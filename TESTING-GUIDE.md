# 🧪 Testing Guide - Ride Booking Platform

## ✅ Database Already Seeded!

Your database now has:
- **4 Riders**: john@example.com, jane@example.com, bob@example.com, alice@example.com
- **3 Drivers**: mike@driver.com, sarah@driver.com, tom@driver.com
- **Password (all)**: password123

---

## 🚀 Quick Test with Thunder Client

### 1. Import Thunder Client Collection
1. Open Thunder Client in VS Code
2. Click "Collections" → "Menu" → "Import"
3. Select `thunder-client-requests.json` from project root
4. You'll see 16 pre-configured requests!

### 2. Test Basic Flow (Run these in order)

#### A. Health Checks (Verify all services are running)
- Run: **#12 Health Check - User Service** → Should return `{"status":"healthy"}`
- Run: **#13 Health Check - Driver Service** → Should return `{"status":"healthy"}`
- Run: **#14 Health Check - Ride Service** → Should return `{"status":"healthy"}`
- Run: **#15 Health Check - Payment Service** → Should return `{"status":"healthy"}`

#### B. User Flow
- Run: **#3 Login User** → Returns user data with ID
- Run: **#4 Get User by ID** → Returns user details

#### C. Create Rides (This triggers analytics!)
- Run: **#6 Create Ride (Mumbai)** → Creates ride, publishes to Pub/Sub
- Run: **#7 Create Ride (Delhi)** → Another city for analytics
- Run: **#8 Create Ride (Bangalore)** → Third city

#### D. Complete Ride & Payment
- Run: **#10 Complete Ride** → Marks ride as completed
- Run: **#11 Process Payment** → Processes payment

---

## 📊 Testing Analytics

### Step 1: Generate Multiple Rides

Run **#16 Bulk Create Rides** multiple times (10-20 times):
- Change the `city` field between: `Mumbai`, `Delhi`, `Bangalore`
- Each ride publishes an event to Pub/Sub
- Analytics job aggregates by city every 60 seconds

### Step 2: Wait for Analytics Processing

The analytics job runs every **60 seconds**. After creating rides:
1. Wait 1-2 minutes
2. Check Firestore for results

### Step 3: View Analytics in Firestore

```bash
# Check Firestore data
gcloud firestore databases list --project=careful-cosine-478715-a0

# Query ride analytics collection
gcloud firestore documents list ride_analytics --project=careful-cosine-478715-a0
```

**OR** Use GCP Console:
1. Open: https://console.cloud.google.com/firestore/databases?project=careful-cosine-478715-a0
2. Click on `ride_analytics` collection
3. You should see documents with:
   - `city`: Mumbai/Delhi/Bangalore
   - `count`: Number of rides
   - `windowEnd`: Timestamp
   - `timestamp`: Processing time

### Step 4: Check Analytics Job Logs

```bash
# SSH into Dataproc
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --project=careful-cosine-478715-a0

# On the cluster, check logs
cat /tmp/analytics.log

# Check if process is running
ps aux | grep ride_analytics

# If not running, start it:
bash /tmp/install_and_run.sh
```

---

## 🔍 Manual Testing with cURL

### Register New User
```bash
curl -X POST http://localhost:8001/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "New User",
    "email": "newuser@test.com",
    "password": "password123",
    "user_type": "rider",
    "city": "Mumbai"
  }'
```

### Create Ride (Triggers Analytics)
```bash
curl -X POST http://localhost:8003/ride/start \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": 2,
    "pickup_location": "Andheri",
    "dropoff_location": "Bandra",
    "city": "Mumbai"
  }'
```

### Check Pub/Sub Messages
```bash
# List Pub/Sub topics
gcloud pubsub topics list --project=careful-cosine-478715-a0

# Pull messages from results topic (to see processed analytics)
gcloud pubsub subscriptions pull ride-booking-rides-flink --limit=5 --project=careful-cosine-478715-a0
```

---

## 🎯 Expected Analytics Flow

1. **User creates ride** → POST to `/ride/start`
2. **Ride service** → Publishes event to Pub/Sub `ride-booking-rides` topic
3. **Analytics job (Dataproc)** → Listens to subscription `ride-booking-rides-flink`
4. **Every 60 seconds** → Aggregates rides by city
5. **Publishes results** → To `ride-booking-ride-results` topic
6. **Writes to Firestore** → `ride_analytics` collection with city counts

---

## 🐛 Troubleshooting

### Frontend "Not Found" Error
The backend API works fine. Frontend issue likely due to:
1. Frontend might not be restarted after config changes
2. Kill frontend process and restart: `cd frontend/nextjs-ui && npm run dev`

### Analytics Not Working
```bash
# 1. Check if Dataproc cluster is running
gcloud dataproc clusters list --region=asia-south1 --project=careful-cosine-478715-a0

# 2. Check if analytics job is running
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --project=careful-cosine-478715-a0 --command="ps aux | grep ride_analytics"

# 3. View logs
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --project=careful-cosine-478715-a0 --command="cat /tmp/analytics.log"

# 4. Restart analytics job
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --project=careful-cosine-478715-a0 --command="pkill -f ride_analytics && bash /tmp/install_and_run.sh"
```

### Port Forwards Not Working
```powershell
# Kill all kubectl processes
Get-Process kubectl | Stop-Process -Force

# Restart port forwards
scripts\fix-all-port-forwards.ps1
```

---

## 📈 Sample Analytics Output

After creating 10 rides (5 Mumbai, 3 Delhi, 2 Bangalore), Firestore should show:

```json
{
  "city": "Mumbai",
  "count": 5,
  "windowEnd": "2025-11-22T10:30:00.000Z",
  "timestamp": "2025-11-22T10:30:00.000Z"
}

{
  "city": "Delhi",
  "count": 3,
  "windowEnd": "2025-11-22T10:30:00.000Z",
  "timestamp": "2025-11-22T10:30:00.000Z"
}

{
  "city": "Bangalore",
  "count": 2,
  "windowEnd": "2025-11-22T10:30:00.000Z",
  "timestamp": "2025-11-22T10:30:00.000Z"
}
```

---

## ✅ Success Indicators

- ✅ All health checks return `200 OK`
- ✅ Rides are created successfully
- ✅ Firestore `ride_analytics` collection has documents
- ✅ Pub/Sub topics show message activity
- ✅ Analytics logs show "Processed ride event" messages

Happy Testing! 🎉

