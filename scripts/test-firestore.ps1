# Quick Test Script for Firestore Analytics
Write-Host "`n=== Testing GCP Analytics Pipeline ===" -ForegroundColor Cyan

Write-Host "`n1. Creating 5 test rides..." -ForegroundColor Yellow
1..5 | ForEach-Object {
    $city = if ($_ % 2 -eq 0) { "Mumbai" } else { "Delhi" }
    $ride = @{
        rider_id = 1
        driver_id = $_
        pickup = "Location $_"
        drop = "Destination $_"
        city = $city
    } | ConvertTo-Json
    
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8003/ride/start" -Method POST -Body $ride -ContentType "application/json"
        Write-Host "  ✅ Ride $_ created (ID: $($result.ride_id), City: $city)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Failed: $_" -ForegroundColor Red
    }
    Start-Sleep -Seconds 2
}

Write-Host "`n2. Waiting 65 seconds for aggregation window..." -ForegroundColor Yellow
Write-Host "   (Analytics script aggregates data every 60 seconds)" -ForegroundColor Cyan
$progress = 0
while ($progress -lt 65) {
    Start-Sleep -Seconds 5
    $progress += 5
    Write-Host "   Waiting... $progress/65 seconds" -ForegroundColor Gray
}

Write-Host "`n3. Checking Firestore data..." -ForegroundColor Yellow
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command='python3 -c "from google.cloud import firestore; db = firestore.Client(database=\"ride-booking-analytics\"); docs = list(db.collection(\"ride_analytics\").limit(10).stream()); print(f\"Found {len(docs)} documents\"); [print(f\"  {doc.id}: {doc.to_dict()}\") for doc in docs]"' 2>&1

Write-Host "`n✅ Test complete! Check the output above for Firestore data." -ForegroundColor Green
Write-Host "`n💡 Tip: If no data appears, check:" -ForegroundColor Cyan
Write-Host "   - Analytics script is running (ps aux | grep ride_analytics)" -ForegroundColor White
Write-Host "   - Script logs (/tmp/analytics.log)" -ForegroundColor White
Write-Host "   - Pub/Sub messages (gcloud pubsub subscriptions pull)" -ForegroundColor White

