# Restart Analytics Script with Fixed Database Connection
Write-Host "`n=== Restarting Analytics Script ===" -ForegroundColor Cyan

Write-Host "`n1. Stopping old script..." -ForegroundColor Yellow
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="pkill -f ride_analytics_standalone.py" 2>&1 | Out-Null
Start-Sleep -Seconds 3

Write-Host "`n2. Downloading fixed script..." -ForegroundColor Yellow
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="cd /tmp && gsutil cp gs://careful-cosine-478715-a0-dataproc-staging-8bf85efcc32f4f5d/flink-jobs/ride_analytics_standalone.py ." 2>&1 | Out-Null

Write-Host "`n3. Starting script with environment variables..." -ForegroundColor Yellow
$startCmd = "cd /tmp && export PUBSUB_PROJECT_ID='careful-cosine-478715-a0' && export PUBSUB_RIDES_SUBSCRIPTION='ride-booking-rides-flink' && export PUBSUB_RESULTS_TOPIC='ride-booking-ride-results' && export FIRESTORE_COLLECTION='ride_analytics' && nohup python3 ride_analytics_standalone.py > analytics.log 2>&1 & sleep 5 && ps aux | grep ride_analytics | grep -v grep"

gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="$startCmd" 2>&1

Write-Host "`n4. Checking script logs..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b --command="tail -20 /tmp/analytics.log 2>/dev/null || echo 'Log file not ready yet'" 2>&1 | Select-Object -Last 20

Write-Host "`n✅ Analytics script restarted!" -ForegroundColor Green
Write-Host "`nNow create a ride from frontend and wait 60 seconds to see data in Firestore." -ForegroundColor Cyan

