# PowerShell script to start all port-forwards for ride-booking services
# This ensures all 4 services are accessible simultaneously

Write-Host "=== Starting Port Forwards for All Services ==="

# Get pod names
$userPod = kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}'
$driverPod = kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}'
$ridePod = kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}'
$paymentPod = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

Write-Host "Pods found:"
Write-Host "  User: $userPod"
Write-Host "  Driver: $driverPod"
Write-Host "  Ride: $ridePod"
Write-Host "  Payment: $paymentPod"

# Kill any existing kubectl port-forwards
Write-Host "`nCleaning up existing port-forwards..."
Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start port-forwards in separate windows
Write-Host "`nStarting port-forwards..."

# User Service: listens on 8001, forward to 8001
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: user-service (8001:8001)'; kubectl port-forward pod/$userPod 8001:8001"

# Driver Service: listens on 8002, forward to 8002
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: driver-service (8002:8002)'; kubectl port-forward pod/$driverPod 8002:8002"

# Ride Service: listens on 8001, forward to 8003
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: ride-service (8003:8001)'; kubectl port-forward pod/$ridePod 8003:8001"

# Payment Service: listens on 8004, forward to 8004
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: payment-service (8004:8004)'; kubectl port-forward pod/$paymentPod 8004:8004"

Write-Host "`n✅ All port-forwards started in separate windows"
Write-Host "Waiting 5 seconds for connections to establish..."
Start-Sleep -Seconds 5

# Test all services
Write-Host "`n=== Testing Services ==="
$services = @{
    8001 = "user-service"
    8002 = "driver-service"
    8003 = "ride-service"
    8004 = "payment-service"
}

$working = 0
foreach ($port in $services.Keys) {
    $service = $services[$port]
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -UseBasicParsing -TimeoutSec 5
        Write-Host "✅ Port $port ($service): WORKING - $($response.Content)"
        $working++
    } catch {
        Write-Host "❌ Port $port ($service): FAILED - $_"
    }
}

Write-Host "`n📊 Summary: $working out of 4 services are working"
if ($working -eq 4) {
    Write-Host "✅ SUCCESS! All services are accessible!"
} else {
    Write-Host "⚠️  Some services need attention. Check the port-forward windows."
}

Write-Host "`n💡 Keep the port-forward windows open to maintain connections."
Write-Host "   To stop: Close the windows or run: Get-Process kubectl | Stop-Process"

