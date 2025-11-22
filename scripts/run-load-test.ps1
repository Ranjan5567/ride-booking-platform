# Simple script to run load test

Write-Host "`n=== Running Load Test ===" -ForegroundColor Cyan

# Check if ride service is accessible
Write-Host "Checking ride service..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8003/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✅ Ride service is accessible!" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to ride service on port 8003" -ForegroundColor Red
    Write-Host "Make sure port-forward is running!" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nStarting load test..." -ForegroundColor Green
Write-Host "Duration: ~4 minutes" -ForegroundColor White
Write-Host "Max users: 50" -ForegroundColor White
Write-Host ""

# Run k6 load test
k6 run --env RIDE_SERVICE_URL=http://localhost:8003 loadtest/ride_service_test.js

Write-Host "`n✅ Load test complete!" -ForegroundColor Green
Write-Host "Check Grafana to see pod scaling!" -ForegroundColor Cyan

