# Comprehensive script to start ALL port-forwards for the ride-booking platform
# This ensures all services and dashboards are accessible simultaneously

Write-Host "========================================"
Write-Host "  Starting All Port Forwards"
Write-Host "========================================"
Write-Host ""

# Step 1: Clean up existing port-forwards
Write-Host "[1/6] Cleaning up existing port-forwards..."
Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  ✅ Cleanup complete"
Write-Host ""

# Step 2: Get all pod/service names
Write-Host "[2/6] Getting pod and service names..."

# Application services
$userPod = kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>&1
$driverPod = kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}' 2>&1
$ridePod = kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}' 2>&1
$paymentPod = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}' 2>&1

# Monitoring services
$promPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>&1
$grafanaPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>&1
$argocdPod = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>&1

Write-Host "  Application Pods:"
Write-Host "    User: $userPod"
Write-Host "    Driver: $driverPod"
Write-Host "    Ride: $ridePod"
Write-Host "    Payment: $paymentPod"
Write-Host "  Monitoring Pods:"
Write-Host "    Prometheus: $promPod"
Write-Host "    Grafana: $grafanaPod"
Write-Host "    ArgoCD: $argocdPod"
Write-Host ""

# Step 3: Start application service port-forwards
Write-Host "[3/6] Starting application service port-forwards..."

# User Service: listens on 8001, forward to 8001
if ($userPod -and $userPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== User Service Port Forward (8001) ==='; kubectl port-forward pod/$userPod 8001:8001"
    Write-Host "  ✅ User Service: http://localhost:8001"
    Start-Sleep -Seconds 1
}

# Driver Service: listens on 8002, forward to 8002
if ($driverPod -and $driverPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Driver Service Port Forward (8002) ==='; kubectl port-forward pod/$driverPod 8002:8002"
    Write-Host "  ✅ Driver Service: http://localhost:8002"
    Start-Sleep -Seconds 1
}

# Ride Service: listens on 8001, forward to 8003
if ($ridePod -and $ridePod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Ride Service Port Forward (8003) ==='; kubectl port-forward pod/$ridePod 8003:8001"
    Write-Host "  ✅ Ride Service: http://localhost:8003"
    Start-Sleep -Seconds 1
}

# Payment Service: listens on 8004, forward to 8004
if ($paymentPod -and $paymentPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Payment Service Port Forward (8004) ==='; kubectl port-forward pod/$paymentPod 8004:8004"
    Write-Host "  ✅ Payment Service: http://localhost:8004"
    Start-Sleep -Seconds 1
}

Write-Host ""

# Step 4: Start monitoring dashboard port-forwards
Write-Host "[4/6] Starting monitoring dashboard port-forwards..."

# Prometheus
if ($promPod -and $promPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Prometheus Port Forward (9090) ==='; kubectl port-forward -n monitoring pod/$promPod 9090:9090"
    Write-Host "  ✅ Prometheus: http://localhost:9090"
    Start-Sleep -Seconds 1
} else {
    # Try service-based port-forward
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Prometheus Port Forward (9090) ==='; kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
    Write-Host "  ✅ Prometheus (via service): http://localhost:9090"
    Start-Sleep -Seconds 1
}

# Grafana
if ($grafanaPod -and $grafanaPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Grafana Port Forward (3001) ==='; kubectl port-forward -n monitoring pod/$grafanaPod 3001:80"
    Write-Host "  ✅ Grafana: http://localhost:3001"
    Start-Sleep -Seconds 1
} else {
    # Try service-based port-forward
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== Grafana Port Forward (3001) ==='; kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80"
    Write-Host "  ✅ Grafana (via service): http://localhost:3001"
    Start-Sleep -Seconds 1
}

# ArgoCD
if ($argocdPod -and $argocdPod -notlike "*Error*") {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== ArgoCD Port Forward (8080) ==='; kubectl port-forward -n argocd pod/$argocdPod 8080:8080"
    Write-Host "  ✅ ArgoCD: http://localhost:8080"
    Start-Sleep -Seconds 1
} else {
    # Try service-based port-forward
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host '=== ArgoCD Port Forward (8080) ==='; kubectl port-forward -n argocd svc/argocd-server 8080:443"
    Write-Host "  ✅ ArgoCD (via service): http://localhost:8080"
    Start-Sleep -Seconds 1
}

Write-Host ""

# Step 5: Wait for connections to establish
Write-Host "[5/6] Waiting for connections to establish..."
Start-Sleep -Seconds 8
Write-Host "  ✅ Connections established"
Write-Host ""

# Step 6: Test all services
Write-Host "[6/6] Testing all services..."
Write-Host ""

$services = @{
    8001 = "User Service"
    8002 = "Driver Service"
    8003 = "Ride Service"
    8004 = "Payment Service"
}

$dashboards = @{
    3001 = "Grafana"
    9090 = "Prometheus"
    8080 = "ArgoCD"
}

$workingServices = 0
$workingDashboards = 0

Write-Host "  Application Services:"
foreach ($port in $services.Keys) {
    $name = $services[$port]
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "    ✅ Port $port ($name): WORKING"
        $workingServices++
    } catch {
        Write-Host "    ❌ Port $port ($name): NOT WORKING"
    }
}

Write-Host ""
Write-Host "  Monitoring Dashboards:"
foreach ($port in $dashboards.Keys) {
    $name = $dashboards[$port]
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "    ✅ Port $port ($name): WORKING"
        $workingDashboards++
    } catch {
        Write-Host "    ❌ Port $port ($name): NOT WORKING"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Summary"
Write-Host "========================================"
Write-Host "  Application Services: $workingServices / 4 working"
Write-Host "  Monitoring Dashboards: $workingDashboards / 3 working"
Write-Host ""
Write-Host "  💡 Keep all port-forward windows open!"
Write-Host "  💡 To stop: Close the windows or run: Get-Process kubectl | Stop-Process"
Write-Host ""
Write-Host "  📊 Access URLs:"
Write-Host "    - User Service: http://localhost:8001"
Write-Host "    - Driver Service: http://localhost:8002"
Write-Host "    - Ride Service: http://localhost:8003"
Write-Host "    - Payment Service: http://localhost:8004"
Write-Host "    - Grafana: http://localhost:3001"
Write-Host "    - Prometheus: http://localhost:9090"
Write-Host "    - ArgoCD: http://localhost:8080"
Write-Host ""


