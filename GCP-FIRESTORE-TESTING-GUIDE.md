# 🔍 GCP Firestore Testing Guide

## ❓ Why Firestore is Empty

The analytics script uses a **60-second aggregation window**. This means:

1. ✅ Messages are received from Pub/Sub
2. ✅ Messages are aggregated by city
3. ⏳ Data is written to Firestore **only every 60 seconds** (when window expires)
4. ⏳ Data is written when the script flushes aggregates

**This is by design** - the script aggregates ride counts per city per minute, not per individual ride.

---

## 🧪 How to Test the Full Pipeline

### **Step 1: Create Multiple Test Rides**

The script needs multiple rides to aggregate. Create at least 3-5 rides:

```bash
# Via API (using PowerShell)
$rides = @(
    @{ rider_id = 1; driver_id = 1; pickup = "Mumbai Airport"; drop = "Mumbai Central"; city = "Mumbai" },
    @{ rider_id = 1; driver_id = 2; pickup = "Andheri"; drop = "Bandra"; city = "Mumbai" },
    @{ rider_id = 2; driver_id = 3; pickup = "Delhi Airport"; drop = "Connaught Place"; city = "Delhi" },
    @{ rider_id = 2; driver_id = 4; pickup = "Bangalore Airport"; drop = "MG Road"; city = "Bangalore" },
    @{ rider_id = 1; driver_id = 5; pickup = "Pune Station"; drop = "Pune Airport"; city = "Pune" }
)

foreach ($ride in $rides) {
    $json = $ride | ConvertTo-Json
    Invoke-RestMethod -Uri "http://localhost:8003/ride/start" -Method POST -Body $json -ContentType "application/json"
    Start-Sleep -Seconds 2
}
```

**Or use the frontend:**
1. Go to http://localhost:3000/book
2. Book 5-10 rides with different cities
3. Wait 60-70 seconds

---

### **Step 2: Wait for Aggregation Window**

The script flushes data every **60 seconds**. After creating rides:

```bash
# Wait 65 seconds to ensure window has expired
Start-Sleep -Seconds 65
```

---

### **Step 3: Check Firestore**

#### **Option A: Via GCP Console**
1. Go to: https://console.cloud.google.com/firestore
2. Select database: `ride-booking-analytics`
3. Click on collection: `ride_analytics`
4. You should see documents like:
   - `Mumbai-1734876543`
   - `Delhi-1734876543`
   - `Bangalore-1734876543`

#### **Option B: Via gcloud CLI**
```bash
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="python3 << 'EOF'
from google.cloud import firestore
db = firestore.Client(database='ride-booking-analytics')
docs = list(db.collection('ride_analytics').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(10).stream())
print(f'Found {len(docs)} documents')
for doc in docs:
    print(f'{doc.id}: {doc.to_dict()}')
EOF"
```

---

## 🔍 Troubleshooting

### **Issue: Still No Data After 60 Seconds**

#### **Check 1: Is Analytics Script Running?**
```bash
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b \
  --command="ps aux | grep ride_analytics | grep -v grep"
```

**Expected:** Should show process running

#### **Check 2: Check Script Logs**
```bash
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b \
  --command="tail -50 /tmp/analytics.log"
```

**Look for:**
- ✅ "Listening for messages..."
- ✅ "Processed ride event: city=..."
- ✅ "Written to Firestore: ..."
- ❌ Any error messages

#### **Check 3: Are Messages in Pub/Sub?**
```bash
gcloud pubsub subscriptions pull ride-booking-rides-flink \
  --limit=5 \
  --project=careful-cosine-478715-a0
```

**Expected:** Should show recent ride messages

#### **Check 4: Is Script Receiving Messages?**
The logs should show:
```
Processed ride event: city=Mumbai
Processed ride event: city=Delhi
```

If you don't see these, the script isn't receiving messages.

---

## 🎯 Quick Test Script

Save this as `test-analytics.ps1`:

```powershell
Write-Host "Creating 5 test rides..." -ForegroundColor Cyan
1..5 | ForEach-Object {
    $ride = @{
        rider_id = 1
        driver_id = $_
        pickup = "Location $_"
        drop = "Destination $_"
        city = if ($_ % 2 -eq 0) { "Mumbai" } else { "Delhi" }
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8003/ride/start" -Method POST -Body $ride -ContentType "application/json"
        Write-Host "✅ Ride $_ created (ID: $($result.ride_id))" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed: $_" -ForegroundColor Red
    }
    Start-Sleep -Seconds 2
}

Write-Host "`nWaiting 65 seconds for aggregation window..." -ForegroundColor Yellow
Start-Sleep -Seconds 65

Write-Host "`nChecking Firestore..." -ForegroundColor Cyan
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="python3 << 'EOF'
from google.cloud import firestore
db = firestore.Client(database='ride-booking-analytics')
docs = list(db.collection('ride_analytics').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(5).stream())
print(f'Found {len(docs)} documents')
for doc in docs:
    data = doc.to_dict()
    print(f'  {doc.id}: {data.get(\"city\")} - {data.get(\"count\")} rides')
EOF"
```

Run it:
```bash
powershell -File test-analytics.ps1
```

---

## 📊 Expected Firestore Data Structure

Each document in `ride_analytics` collection:

```json
{
  "city": "Mumbai",
  "count": 3,
  "windowEnd": "2025-11-22T14:35:00.123456",
  "timestamp": "2025-11-22T14:35:00.123456"
}
```

**Document ID format:** `{city}-{unix_timestamp}`

Example: `Mumbai-1734876543`

---

## ✅ Verification Checklist

- [ ] Analytics script is running (`ps aux | grep ride_analytics`)
- [ ] Created at least 3-5 test rides
- [ ] Waited 60+ seconds after creating rides
- [ ] Checked Firestore console or via CLI
- [ ] See documents in `ride_analytics` collection
- [ ] Documents contain `city`, `count`, `timestamp` fields

---

## 🚀 Full End-to-End Test

1. **Create rides** (5-10 rides with different cities)
2. **Wait 65 seconds** (for aggregation window)
3. **Check Firestore** (should see aggregated data)
4. **Check Pub/Sub results topic** (should see aggregated messages)
5. **Check analytics logs** (should show processing)

---

## 📝 Notes

- **Aggregation Window:** 60 seconds (configurable in script)
- **Collection Name:** `ride_analytics` (configurable via env var)
- **Database:** `ride-booking-analytics`
- **Data Format:** Aggregated counts per city per minute

The script **intentionally aggregates** data - you won't see individual rides, only city-level counts per time window!

