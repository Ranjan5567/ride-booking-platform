from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
import os
from typing import Optional
import uvicorn

app = FastAPI(title="User Service", version="1.0.0")

# Database connection
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
class UserRegister(BaseModel):
    name: str
    email: str
    password: str
    user_type: str  # "rider" or "driver"
    city: Optional[str] = None

class UserLogin(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    user_type: str
    city: Optional[str] = None

@app.on_event("startup")
async def startup():
    # Initialize database tables
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            user_type VARCHAR(50) NOT NULL,
            city VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cities (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    cursor.close()
    conn.close()

@app.post("/user/register", response_model=UserResponse)
async def register_user(user: UserRegister):
    """Register a new user (rider or driver)"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Insert user
        cursor.execute("""
            INSERT INTO users (name, email, password, user_type, city)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id, name, email, user_type, city
        """, (user.name, user.email, user.password, user.user_type, user.city))
        
        result = cursor.fetchone()
        conn.commit()
        
        # Insert city if provided
        if user.city:
            cursor.execute("""
                INSERT INTO cities (name) VALUES (%s)
                ON CONFLICT (name) DO NOTHING
            """, (user.city,))
            conn.commit()
        
        return UserResponse(
            id=result[0],
            name=result[1],
            email=result[2],
            user_type=result[3],
            city=result[4]
        )
    except psycopg2.IntegrityError:
        raise HTTPException(status_code=400, detail="Email already exists")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.post("/user/login", response_model=UserResponse)
async def login_user(credentials: UserLogin):
    """Login user (mock authentication)"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, name, email, user_type, city
            FROM users
            WHERE email = %s AND password = %s
        """, (credentials.email, credentials.password))
        
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        return UserResponse(
            id=result[0],
            name=result[1],
            email=result[2],
            user_type=result[3],
            city=result[4]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/user/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    """Get user by ID"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, name, email, user_type, city
            FROM users
            WHERE id = %s
        """, (user_id,))
        
        result = cursor.fetchone()
        if not result:
            raise HTTPException(status_code=404, detail="User not found")
        
        return UserResponse(
            id=result[0],
            name=result[1],
            email=result[2],
            user_type=result[3],
            city=result[4]
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
    return {"status": "healthy", "service": "user-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)

