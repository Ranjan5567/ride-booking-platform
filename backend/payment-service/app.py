from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Payment Service: Processes ride payments (simplified - always succeeds for demo)
# Called by Ride Service during ride creation
app = FastAPI(title="Payment Service", version="1.0.0")

# CORS middleware - allows frontend and other services to call this
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class PaymentRequest(BaseModel):
    ride_id: int
    amount: float

class PaymentResponse(BaseModel):
    status: str
    ride_id: int
    amount: float
    transaction_id: str

@app.post("/payment/process", response_model=PaymentResponse)
async def process_payment(payment: PaymentRequest):
    """Payment processing endpoint - called by Ride Service via HTTP
    In production, this would integrate with payment gateways (Stripe, PayPal, etc.)
    For demo: always returns SUCCESS"""
    # Simulate instant payment success
    transaction_id = f"TXN{payment.ride_id}{payment.amount}"
    
    return PaymentResponse(
        status="SUCCESS",
        ride_id=payment.ride_id,
        amount=payment.amount,
        transaction_id=transaction_id
    )

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "payment-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8004)

