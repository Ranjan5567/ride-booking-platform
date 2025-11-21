# Fix all port-forwards - hybrid approach for ride-service issue
# This script ensures all 4 services work simultaneously

Write-Host "=== Fixing All Port Forwards ==="

# Kill all existing kubectl processes
Write-Host "`nStep 1: Cleaning up existing port-forwards..."
Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Get pod names
Write-Host "`nStep 2: Getting pod names..."
$userPod = kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}'
$driverPod = kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}'
$ridePod = kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}'
$paymentPod = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

Write-Host "  User: $userPod"
Write-Host "  Driver: $driverPod"
Write-Host "  Ride: $ridePod"
Write-Host "  Payment: $paymentPod"

# Start port-forwards
Write-Host "`nStep 3: Starting port-forwards..."
Write-Host "  Using SERVICE port-forwards for: user, driver, payment (more stable)"
Write-Host "  Using POD port-forward for: ride (because it listens on 8001, not 8003)"

# Service-based port-forwards (more stable)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: user-service (8001:80)'; kubectl port-forward svc/user-service 8001:80"
Start-Sleep -Seconds 1

Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: driver-service (8002:80)'; kubectl port-forward svc/driver-service 8002:80"
Start-Sleep -Seconds 1

# Direct pod port-forward for ride-service (listens on 8001, not 8003)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: ride-service (8003:8001) - DIRECT POD'; kubectl port-forward pod/$ridePod 8003:8001"
Start-Sleep -Seconds 1

Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Port-forward: payment-service (8004:80)'; kubectl port-forward svc/payment-service 8004:80"
Start-Sleep -Seconds 1

Write-Host "`n✅ All port-forwards started in separate windows"
Write-Host "Waiting 5 seconds for connections..."
Start-Sleep -Seconds 5

# Test all services
Write-Host "`nStep 4: Testing all services..."
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
        Write-Host "  ✅ Port $port ($service): WORKING - $($response.Content)"
        $working++
    } catch {
        Write-Host "  ❌ Port $port ($service): FAILED - $_"
    }
}

Write-Host "`n📊 Summary: $working out of 4 services are working"
if ($working -eq 4) {
    Write-Host "✅ SUCCESS! All 4 services are now accessible!"
    Write-Host "`nKeep the 4 port-forward windows open to maintain connections."
} else {
    Write-Host "⚠️  $($services.Count - $working) service(s) still need attention."
    Write-Host "   Check the port-forward windows for errors."
}

Write-Host "`nTo stop all port-forwards: Get-Process kubectl | Stop-Process"

