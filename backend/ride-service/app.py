from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import os
import httpx
import json
import base64
from typing import Optional
import uvicorn
from google.cloud import pubsub_v1
from google.cloud import firestore
from google.oauth2 import service_account
from collections import defaultdict

app = FastAPI(title="Ride Service", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "ridebooking")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_PORT = os.getenv("DB_PORT", "5432")

# Service URLs
PAYMENT_SERVICE_URL = os.getenv("PAYMENT_SERVICE_URL", "http://payment-service:8004")
LAMBDA_API_URL = os.getenv("LAMBDA_API_URL", "")
PUBSUB_PROJECT_ID = os.getenv("PUBSUB_PROJECT_ID", "")
PUBSUB_RIDES_TOPIC = os.getenv("PUBSUB_RIDES_TOPIC", "")
PUBSUB_CREDENTIALS_B64 = os.getenv("PUBSUB_PUBLISHER_CREDENTIALS", "")
DISABLE_NOTIFICATIONS = os.getenv("DISABLE_NOTIFICATIONS", "false").lower() == "true"

pubsub_publisher = None
PUBSUB_TOPIC_PATH = None

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

    init_pubsub()

def init_pubsub():
    """Initialize Pub/Sub publisher client"""
    global pubsub_publisher, PUBSUB_TOPIC_PATH

    if not PUBSUB_PROJECT_ID or not PUBSUB_RIDES_TOPIC:
        print("Pub/Sub configuration missing, skipping publisher init")
        return

    credentials = None
    if PUBSUB_CREDENTIALS_B64:
        try:
            credentials_json = base64.b64decode(PUBSUB_CREDENTIALS_B64).decode("utf-8")
            credentials_info = json.loads(credentials_json)
            credentials = service_account.Credentials.from_service_account_info(credentials_info)
        except Exception as exc:
            print(f"Unable to parse Pub/Sub credentials: {exc}")

    try:
        pubsub_publisher = pubsub_v1.PublisherClient(credentials=credentials)
        PUBSUB_TOPIC_PATH = pubsub_publisher.topic_path(PUBSUB_PROJECT_ID, PUBSUB_RIDES_TOPIC)
        print(f"Configured Pub/Sub publisher for topic {PUBSUB_TOPIC_PATH}")
    except Exception as exc:
        print(f"Failed to initialize Pub/Sub publisher: {exc}")
        pubsub_publisher = None
        PUBSUB_TOPIC_PATH = None

async def publish_to_pubsub(ride_data: dict):
    """Publish ride event to Google Pub/Sub"""
    global pubsub_publisher, PUBSUB_TOPIC_PATH

    if not pubsub_publisher or not PUBSUB_TOPIC_PATH:
        print("Pub/Sub publisher not configured, skipping publish")
        return

    try:
        future = pubsub_publisher.publish(
            PUBSUB_TOPIC_PATH,
            json.dumps(ride_data).encode("utf-8"),
            city=ride_data.get("city", "unknown")
        )
        future.result(timeout=10)
        print(f"Published ride event to Pub/Sub: {ride_data}")
    except Exception as e:
        print(f"Error publishing to Pub/Sub: {str(e)}")
        # Don't fail the request if Pub/Sub is unavailable

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
        await publish_to_pubsub(ride_event)
        
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
    """Get latest analytics data from Firestore"""
    try:
        # Get Firestore configuration from environment
        firestore_project_id = os.getenv("PUBSUB_PROJECT_ID", "careful-cosine-478715-a0")
        firestore_database = os.getenv("FIRESTORE_DATABASE", "ride-booking-analytics")
        firestore_collection = os.getenv("FIRESTORE_COLLECTION", "ride_analytics")
        
        # Initialize Firestore client with credentials if available
        credentials = None
        if PUBSUB_CREDENTIALS_B64:
            try:
                credentials_json = base64.b64decode(PUBSUB_CREDENTIALS_B64).decode("utf-8")
                credentials_info = json.loads(credentials_json)
                from google.oauth2 import service_account
                credentials = service_account.Credentials.from_service_account_info(credentials_info)
            except Exception as cred_error:
                print(f"Warning: Could not parse credentials for Firestore: {cred_error}")
        
        if credentials:
            db = firestore.Client(project=firestore_project_id, database=firestore_database, credentials=credentials)
        else:
            # Try without explicit credentials (use default)
            db = firestore.Client(project=firestore_project_id, database=firestore_database)
        
        # Query all documents from ride_analytics collection
        docs = list(db.collection(firestore_collection).stream())
        
        if not docs:
            # Return empty array if no data
            return []
        
        # Aggregate by city (sum all counts per city)
        city_aggregates = defaultdict(int)
        latest_timestamps = {}
        
        for doc in docs:
            data = doc.to_dict()
            city = data.get("city", "unknown")
            count = data.get("count", 0)
            timestamp = data.get("timestamp", "")
            
            # Sum counts per city
            city_aggregates[city] += count
            
            # Track latest timestamp per city
            if city not in latest_timestamps or timestamp > latest_timestamps[city]:
                latest_timestamps[city] = timestamp
        
        # Convert to list format expected by frontend
        result = [
            {
                "city": city,
                "count": total_count,
                "timestamp": latest_timestamps.get(city, "")
            }
            for city, total_count in sorted(city_aggregates.items(), key=lambda x: x[1], reverse=True)
        ]
        
        return result
        
    except Exception as e:
        # Fallback to mock data if Firestore query fails
        import traceback
        print(f"Error querying Firestore: {e}")
        traceback.print_exc()
        return [
            {"city": "Mumbai", "count": 0, "timestamp": ""},
            {"city": "Delhi", "count": 0, "timestamp": ""},
        ]

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "ride-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8003)
