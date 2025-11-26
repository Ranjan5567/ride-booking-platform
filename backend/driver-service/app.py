from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import os
from typing import Optional
import uvicorn

# Driver Service: Manages driver profiles, vehicle info, and online/offline status
# Runs on AWS EKS alongside other microservices
app = FastAPI(title="Driver Service", version="1.0.0")

# CORS middleware - allows frontend to call this service
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection - AWS RDS PostgreSQL (shared database with other services)
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "ridebooking")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )

# Models
class DriverCreate(BaseModel):
    user_id: int
    vehicle_number: str
    vehicle_type: str
    license_number: str

class DriverStatus(BaseModel):
    driver_id: int
    status: str  # "online" or "offline"

class DriverResponse(BaseModel):
    id: int
    user_id: int
    vehicle_number: str
    vehicle_type: str
    license_number: str
    status: str

@app.on_event("startup")
async def startup():
    # Creates drivers table in RDS - stores driver profiles and vehicle information
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS drivers (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            vehicle_number VARCHAR(50) NOT NULL,
            vehicle_type VARCHAR(50) NOT NULL,
            license_number VARCHAR(100) NOT NULL,
            status VARCHAR(20) DEFAULT 'offline',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cursor.close()
    conn.close()

@app.post("/driver/create", response_model=DriverResponse)
async def create_driver(driver: DriverCreate):
    """Create a new driver"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO drivers (user_id, vehicle_number, vehicle_type, license_number, status)
            VALUES (%s, %s, %s, %s, 'offline')
            RETURNING id, user_id, vehicle_number, vehicle_type, license_number, status
        """, (driver.user_id, driver.vehicle_number, driver.vehicle_type, driver.license_number))
        
        result = cursor.fetchone()
        conn.commit()
        
        return DriverResponse(
            id=result[0],
            user_id=result[1],
            vehicle_number=result[2],
            vehicle_type=result[3],
            license_number=result[4],
            status=result[5]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.put("/driver/status", response_model=DriverResponse)
async def update_driver_status(status: DriverStatus):
    """Update driver status (online/offline) - used to track driver availability"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        if status.status not in ["online", "offline"]:
            raise HTTPException(status_code=400, detail="Status must be 'online' or 'offline'")
        
        cursor.execute("""
            UPDATE drivers
            SET status = %s
            WHERE id = %s
            RETURNING id, user_id, vehicle_number, vehicle_type, license_number, status
        """, (status.status, status.driver_id))
        
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Driver not found")
        
        conn.commit()
        
        return DriverResponse(
            id=result[0],
            user_id=result[1],
            vehicle_number=result[2],
            vehicle_type=result[3],
            license_number=result[4],
            status=result[5]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/driver/{driver_id}", response_model=DriverResponse)
async def get_driver(driver_id: int):
    """Get driver by ID"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, user_id, vehicle_number, vehicle_type, license_number, status
            FROM drivers
            WHERE id = %s
        """, (driver_id,))
        
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="Driver not found")
        
        return DriverResponse(
            id=result[0],
            user_id=result[1],
            vehicle_number=result[2],
            vehicle_type=result[3],
            license_number=result[4],
            status=result[5]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "driver-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)

