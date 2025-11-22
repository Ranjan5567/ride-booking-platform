# 🚗 Ride Booking Platform - Frontend User Guide

## 📝 Step-by-Step Guide

### Step 1: Login ✅
1. Go to http://localhost:3000
2. Enter credentials:
   - **Email:** `john@example.com`
   - **Password:** `password123`
3. Click **"Login"** button

**You'll be automatically redirected to the Book Ride page!**

---

## 🎯 Step 2: Book a Ride

After login, you'll see the **"Book a Ride"** page with a form.

### Fill in the form:

**Example 1: Mumbai Ride**
```
Pickup Location:   Andheri, Mumbai
Drop Location:     Bandra, Mumbai
City:              Mumbai
Driver ID:         5  (Driver Mike from Mumbai)
```

**Example 2: Delhi Ride**
```
Pickup Location:   Connaught Place
Drop Location:     India Gate
City:              Delhi
Driver ID:         6  (Driver Sarah from Delhi)
```

**Example 3: Bangalore Ride**
```
Pickup Location:   Koramangala
Drop Location:     MG Road
City:              Bangalore
Driver ID:         7  (Driver Tom from Bangalore)
```

### Available Drivers:
| Driver ID | Name | City |
|-----------|------|------|
| 5 | Driver Mike | Mumbai |
| 6 | Driver Sarah | Delhi |
| 7 | Driver Tom | Bangalore |

---

## 🎉 Step 3: Submit & See the Magic!

1. Click **"Book Ride"** button
2. You'll see a success message:
   ```
   ✅ Ride started successfully! Ride ID: [number]
   ```

### What Happens Behind the Scenes:

**🔄 Microservices Flow:**
```
1. Frontend → Ride Service (Port 8003)
2. Ride Service → RDS Database (Save ride)
3. Ride Service → Pub/Sub (Publish event to GCP)
4. Ride Service → Lambda (Send notification)
```

**📊 GCP Analytics Flow:**
```
1. Pub/Sub receives ride event
2. Dataproc Flink job processes event
3. Analytics stored in Firestore
4. Real-time ride statistics available
```

---

## 🔍 Step 4: Verify Your Ride

### Option A: Check Database (DBeaver)
```sql
-- View all rides
SELECT * FROM rides ORDER BY created_at DESC;

-- View your specific ride
SELECT r.*, u.name as rider_name, u.email
FROM rides r
JOIN users u ON r.rider_id = u.id
WHERE r.rider_id = 1
ORDER BY r.created_at DESC;
```

### Option B: Check via API (PowerShell)
```powershell
# Get ride details
Invoke-RestMethod -Uri "http://localhost:8003/ride/1" -Method GET | ConvertTo-Json
```

### Option C: Check GCP Firestore
1. Go to: https://console.cloud.google.com/firestore
2. Select project: `careful-cosine-478715-a0`
3. Select database: `ride-booking-analytics`
4. View ride analytics data

---

## 🎨 Frontend Features

### Current Pages:

1. **`/auth` (Login/Register)**
   - Login with existing user
   - Register new user
   - Switch between login/register

2. **`/book` (Book Ride)**
   - Book new rides
   - See success messages
   - Form validation

### User Types:

**Riders (can book rides):**
- john@example.com (Mumbai)
- jane@example.com (Delhi)
- bob@example.com (Bangalore)
- alice@example.com (Chennai)

**Drivers (provide rides):**
- mike@driver.com (Mumbai)
- sarah@driver.com (Delhi)
- tom@driver.com (Bangalore)

**All passwords:** `password123`

---

## 🧪 Testing Scenarios

### Scenario 1: Single Ride
```
1. Login as john@example.com
2. Book ride from "Andheri" to "Bandra" in "Mumbai"
3. Use Driver ID: 5
4. Submit and note the Ride ID
5. Check database to see the ride
```

### Scenario 2: Multiple Rides (For Analytics)
```
1. Login as john@example.com
2. Book 5 rides in Mumbai
3. Check Firestore for aggregated analytics
4. View ride patterns and statistics
```

### Scenario 3: Different Cities
```
1. Login as jane@example.com (Delhi)
2. Book ride in Delhi with Driver ID 6
3. Logout
4. Login as bob@example.com (Bangalore)
5. Book ride in Bangalore with Driver ID 7
6. Compare rides across cities in database
```

### Scenario 4: Register New User
```
1. Go to http://localhost:3000
2. Click "Don't have an account? Register"
3. Fill in:
   - Name: Test User
   - Email: test@example.com
   - Password: password123
   - User Type: Rider
   - City: Mumbai
4. Register and automatically login
5. Book a ride immediately
```

---

## 📊 What You Can Demonstrate

### 1. **Full Stack Architecture**
- ✅ React/Next.js Frontend
- ✅ FastAPI Microservices (Python)
- ✅ PostgreSQL Database (AWS RDS)
- ✅ Kubernetes (AWS EKS)
- ✅ Cloud Integration (AWS + GCP)

### 2. **Microservices Communication**
```
Frontend → User Service → Database
Frontend → Ride Service → Database + Pub/Sub + Lambda
```

### 3. **Multi-Cloud Setup**
- **AWS:** EKS, RDS, Lambda, API Gateway
- **GCP:** Dataproc (Flink), Pub/Sub, Firestore

### 4. **Real-Time Analytics**
- Ride events published to Pub/Sub
- Flink processes events in real-time
- Analytics stored in Firestore
- Queryable via GCP Console

### 5. **Scalability**
- Horizontal Pod Autoscaling (HPA)
- Multiple replicas of each service
- Load balanced via Kubernetes

---

## 🐛 Troubleshooting

### Issue: "Not Found" Error on Login
**Fix:** Check if frontend is using correct API URL
```bash
# Should be localhost:8001 for user service
cat frontend/nextjs-ui/.env.local
# Should show: NEXT_PUBLIC_API_BASE_URL=http://localhost:8001
```

### Issue: "Failed to start ride"
**Fixes:**
1. Check ride-service is running: http://localhost:8003/health
2. Verify port-forward is active
3. Ensure driver_id exists (use 5, 6, or 7)

### Issue: Page doesn't load
**Fixes:**
1. Check frontend is running:
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -eq "node" }
   ```
2. Restart if needed:
   ```powershell
   cd frontend/nextjs-ui
   npm run dev
   ```

### Issue: Login successful but redirect fails
**Fix:** Clear browser localStorage
```javascript
// Open browser console (F12) and run:
localStorage.clear()
// Then try logging in again
```

---

## 🎯 Demo Script (For Presentation)

### **Opening (30 seconds)**
```
"This is a full-stack ride-booking platform 
built on AWS and GCP with Kubernetes orchestration."
```

### **Demo Flow (3-5 minutes)**

**1. Show Architecture (30s)**
- Open FINAL-STATUS.md
- Explain: Frontend → K8s → Microservices → AWS RDS + GCP Analytics

**2. Show Database (30s)**
- Open DBeaver (localhost:5432)
- Show users table
- Show rides table (currently empty or with test data)

**3. Frontend Login (30s)**
- Go to http://localhost:3000
- Login as john@example.com
- Show automatic redirect to Book page

**4. Book Ride (1 min)**
- Fill form with Mumbai ride
- Submit
- Show success message with Ride ID

**5. Verify in Database (30s)**
- Go back to DBeaver
- Refresh rides table
- Show the new ride just created
- Highlight: rider_id, driver_id, pickup, drop, city, status

**6. Show GCP Analytics (1 min)**
- Open GCP Console → Pub/Sub
- Show ride-booking-rides topic with messages
- Open Firestore
- Show ride-booking-analytics database
- Explain: "Real-time analytics pipeline processing ride data"

**7. Show Microservices (30s)**
- Open http://localhost:8001/docs (User Service API)
- Open http://localhost:8003/docs (Ride Service API)
- Show live API documentation

**8. Closing (30s)**
```
"This demonstrates:
- Multi-cloud architecture (AWS + GCP)
- Microservices on Kubernetes
- Real-time analytics with Flink
- Full DevOps pipeline with Terraform & ArgoCD"
```

---

## 🚀 Quick Commands Reference

### Start Everything
```powershell
# Port-forwards
kubectl port-forward service/user-service 8001:80
kubectl port-forward service/ride-service 8003:80
kubectl port-forward pod/psql-tunnel 5432:5432

# Frontend
cd frontend/nextjs-ui
npm run dev
```

### Check Status
```powershell
# Services
kubectl get pods
kubectl get services

# GCP
gcloud dataproc clusters list --region=asia-south1
gcloud pubsub topics list
```

### Create Test Rides
```powershell
# Create 5 rides for analytics testing
1..5 | ForEach-Object {
    Invoke-RestMethod -Uri "http://localhost:8003/ride/start" -Method POST `
      -Body '{"rider_id":1,"driver_id":5,"pickup":"Location A","drop":"Location B","city":"Mumbai"}' `
      -ContentType "application/json"
    Write-Host "Created ride $_"
}
```

---

## 📄 Related Documentation
- `FINAL-STATUS.md` - Complete system status
- `SIMPLE-API-TESTS.md` - API testing guide
- `TESTING-GUIDE.md` - Detailed testing scenarios
- `RDS-ACCESS-TROUBLESHOOTING.md` - Database access guide

---

## ✅ Summary

**After Login, You Can:**
1. ✅ Book rides with different pickup/drop locations
2. ✅ Use different drivers (IDs: 5, 6, 7)
3. ✅ See rides in database immediately
4. ✅ Trigger GCP analytics pipeline
5. ✅ Demonstrate full multi-cloud architecture

**Key URLs:**
- Frontend: http://localhost:3000
- User Service API: http://localhost:8001/docs
- Ride Service API: http://localhost:8003/docs
- Database: localhost:5432 (DBeaver)
- GCP Console: https://console.cloud.google.com

**Test Credentials:**
- Email: john@example.com (or any other seeded user)
- Password: password123

**Everything is ready for your demo! 🎉**

