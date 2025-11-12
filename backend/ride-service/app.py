from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
import os
import httpx
import json
from typing import Optional
import uvicorn

app = FastAPI(title="Ride Service", version="1.0.0")

# Database connection
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "ridebooking")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_PORT = os.getenv("DB_PORT", "5432")

# Service URLs
PAYMENT_SERVICE_URL = os.getenv("PAYMENT_SERVICE_URL", "http://payment-service:8004")
LAMBDA_API_URL = os.getenv("LAMBDA_API_URL", "")
EVENTHUB_CONNECTION_STRING = os.getenv("EVENTHUB_CONNECTION_STRING", "")
DISABLE_NOTIFICATIONS = os.getenv("DISABLE_NOTIFICATIONS", "false").lower() == "true"

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

# Models
class RideStart(BaseModel):
    rider_id: int
    driver_id: int
    pickup: str
    drop: str
    city: str

class RideResponse(BaseModel):
    id: int
    rider_id: int
    driver_id: int
    pickup: str
    drop: str
    city: str
    status: str
    created_at: str

@app.on_event("startup")
async def startup():
    # Initialize database table
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS rides (
            id SERIAL PRIMARY KEY,
            rider_id INTEGER NOT NULL,
            driver_id INTEGER NOT NULL,
            pickup VARCHAR(255) NOT NULL,
            drop_location VARCHAR(255) NOT NULL,
            city VARCHAR(100) NOT NULL,
            status VARCHAR(50) DEFAULT 'started',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cursor.close()
    conn.close()

async def publish_to_eventhub(ride_data: dict):
    """Publish ride event to Azure Event Hub"""
    try:
        from azure.eventhub import EventHubProducerClient, EventData
        
        if not EVENTHUB_CONNECTION_STRING:
            print("EventHub connection string not configured, skipping event publish")
            return
        
        producer = EventHubProducerClient.from_connection_string(
            conn_str=EVENTHUB_CONNECTION_STRING,
            eventhub_name="rides"
        )
        
        with producer:
            event_data = EventData(json.dumps(ride_data))
            producer.send_batch([event_data])
            print(f"Published ride event: {ride_data}")
    except Exception as e:
        print(f"Error publishing to EventHub: {str(e)}")
        # Don't fail the request if EventHub is unavailable

async def call_notification_lambda(ride_id: int, city: str):
    """Call notification Lambda via API Gateway"""
    if DISABLE_NOTIFICATIONS or not LAMBDA_API_URL:
        print("Notifications disabled or API URL not configured")
        return
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                LAMBDA_API_URL,
                json={"ride_id": ride_id, "city": city},
                timeout=5.0
            )
            print(f"Lambda notification sent: {response.status_code}")
    except Exception as e:
        print(f"Error calling Lambda: {str(e)}")
        # Don't fail the request if Lambda is unavailable

@app.post("/ride/start", response_model=dict)
async def start_ride(ride: RideStart):
    """Start a new ride - main service that orchestrates payment, notification, and event publishing"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # 1. Store ride in RDS
        cursor.execute("""
            INSERT INTO rides (rider_id, driver_id, pickup, drop_location, city, status)
            VALUES (%s, %s, %s, %s, %s, 'started')
            RETURNING id, created_at
        """, (ride.rider_id, ride.driver_id, ride.pickup, ride.drop, ride.city))
        
        result = cursor.fetchone()
        ride_id = result[0]
        created_at = result[1]
        conn.commit()
        
        # 2. Call Payment Service
        try:
            async with httpx.AsyncClient() as client:
                payment_response = await client.post(
                    f"{PAYMENT_SERVICE_URL}/payment/process",
                    json={"ride_id": ride_id, "amount": 100.0},
                    timeout=5.0
                )
                payment_data = payment_response.json()
                if payment_data.get("status") != "SUCCESS":
                    raise HTTPException(status_code=402, detail="Payment failed")
        except httpx.RequestError as e:
            print(f"Payment service error: {str(e)}")
            # In demo mode, continue even if payment service is down
        
        # 3. Call Notification Lambda (if enabled)
        await call_notification_lambda(ride_id, ride.city)
        
        # 4. Publish to Azure Event Hub
        ride_event = {
            "ride_id": ride_id,
            "rider_id": ride.rider_id,
            "driver_id": ride.driver_id,
            "pickup": ride.pickup,
            "drop": ride.drop,
            "city": ride.city,
            "timestamp": created_at.isoformat()
        }
        await publish_to_eventhub(ride_event)
        
        return {
            "message": "Ride started successfully",
            "ride_id": ride_id,
            "status": "started"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/ride/all", response_model=list)
async def get_all_rides():
    """Get all rides"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, rider_id, driver_id, pickup, drop_location, city, status, created_at
            FROM rides
            ORDER BY created_at DESC
        """)
        
        rides = []
        for row in cursor.fetchall():
            rides.append({
                "id": row[0],
                "rider_id": row[1],
                "driver_id": row[2],
                "pickup": row[3],
                "drop": row[4],
                "city": row[5],
                "status": row[6],
                "created_at": row[7].isoformat() if row[7] else None
            })
        
        return rides
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/ride/{ride_id}", response_model=RideResponse)
async def get_ride(ride_id: int):
    """Get ride by ID"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, rider_id, driver_id, pickup, drop_location, city, status, created_at
            FROM rides
            WHERE id = %s
        """, (ride_id,))
        
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Ride not found")
        
        return RideResponse(
            id=result[0],
            rider_id=result[1],
            driver_id=result[2],
            pickup=result[3],
            drop=result[4],
            city=result[5],
            status=result[6],
            created_at=result[7].isoformat() if result[7] else None
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/analytics/latest")
async def get_analytics():
    """Get latest analytics data (mock endpoint - in production would query Cosmos DB)"""
    # In production, this would query Cosmos DB
    # For demo, return mock data
    return [
        {"city": "Bangalore", "count": 45, "timestamp": "2024-01-15T10:30:00Z"},
        {"city": "Mumbai", "count": 32, "timestamp": "2024-01-15T10:30:00Z"},
        {"city": "Delhi", "count": 28, "timestamp": "2024-01-15T10:30:00Z"},
        {"city": "Hyderabad", "count": 15, "timestamp": "2024-01-15T10:30:00Z"},
        {"city": "Chennai", "count": 12, "timestamp": "2024-01-15T10:30:00Z"},
    ]

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "ride-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8003)
