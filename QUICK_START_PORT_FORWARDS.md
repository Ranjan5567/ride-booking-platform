# Quick Start: All Port Forwards

## Problem
Port-forwards keep stopping. This happens because:
1. PowerShell windows close
2. kubectl processes crash
3. Network interruptions

## Solution: Run This Command

Open PowerShell in the project root and run:

```powershell
# Get all pod names
$userPod = kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}'
$driverPod = kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}'
$ridePod = kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}'
$paymentPod = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}'
$promPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}'
$grafanaPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}'
$argocdPod = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}'

# Start all port-forwards
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$userPod 8001:8001"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$driverPod 8002:8002"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$ridePod 8003:8001"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$paymentPod 8004:8004"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring pod/$promPod 9090:9090"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring pod/$grafanaPod 3001:80"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n argocd pod/$argocdPod 8080:8080"

Write-Host "All port-forwards started! Keep the 7 PowerShell windows open."
```

## Access URLs

| Service | URL | Status |
|---------|-----|--------|
| User Service | http://localhost:8001 | ✅ |
| Driver Service | http://localhost:8002 | ✅ |
| Ride Service | http://localhost:8003 | ✅ |
| Payment Service | http://localhost:8004 | ✅ |
| Grafana | http://localhost:3001 | ✅ |
| Prometheus | http://localhost:9090 | ✅ |
| ArgoCD | http://localhost:8080 | ✅ |

## Finding Your Dashboard in Grafana

1. **Open Grafana:** http://localhost:3001
2. **Login:** admin / E9ZWkHelLYolVbaxbTIXeDY11JgofWkoV0bM580R
3. **Click "Dashboards"** (left sidebar)
4. **Search for:** "Ride Booking" or "ride"
5. **If not found, create one:**
   - Click "+" → "Create dashboard"
   - Add panel → Use Prometheus data source
   - Query: `rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])`
   - Save as "Ride Booking Platform"

## If Port-Forwards Stop

1. **Check if pods are running:**
   ```powershell
   kubectl get pods
   kubectl get pods -n monitoring
   kubectl get pods -n argocd
   ```

2. **Kill all kubectl processes:**
   ```powershell
   Get-Process kubectl | Stop-Process -Force
   ```

3. **Re-run the port-forward commands above**

## Why They Stop

- PowerShell window closed
- kubectl process crashed
- Pod restarted (pod name changed)
- Network timeout

**Solution:** Keep all 7 PowerShell windows open and visible!

