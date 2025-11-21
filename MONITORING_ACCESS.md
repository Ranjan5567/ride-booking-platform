# Monitoring & Dashboard Access Guide

## 📊 Available Dashboards

### 1. Grafana Dashboard
**URL:** http://localhost:3001

**Credentials:**
- Username: `admin`
- Password: (retrieve with: `kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }`)

**Features:**
- Visualize metrics from Prometheus
- View logs from Loki
- Pre-configured dashboards for Kubernetes and application metrics
- Custom dashboards for ride-booking services

**Port Forward:**
```powershell
kubectl port-forward -n monitoring pod/<grafana-pod> 3001:80
```

---

### 2. Prometheus UI
**URL:** http://localhost:9090

**Authentication:** None required

**Features:**
- Query metrics using PromQL
- View targets and service discovery
- Check alerting rules
- Explore time-series data

**Port Forward:**
```powershell
kubectl port-forward -n monitoring pod/<prometheus-pod> 9090:9090
```

---

### 3. Loki (Log Aggregation)
**URL:** http://localhost:3100

**Features:**
- Centralized log aggregation
- Usually accessed via Grafana's Explore view
- Query logs using LogQL

**Port Forward:**
```powershell
kubectl port-forward -n monitoring pod/<loki-pod> 3100:3100
```

---

### 4. ArgoCD (GitOps Dashboard)
**URL:** http://localhost:8080

**Credentials:**
- Username: `admin`
- Password: (retrieve with: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }`)

**Features:**
- View deployed applications
- Monitor sync status
- Manage GitOps workflows
- Application health and status

**Port Forward:**
```powershell
kubectl port-forward -n argocd pod/<argocd-server-pod> 8080:8080
```

---

## 🚀 Quick Setup Script

To set up all monitoring port-forwards at once:

```powershell
# Get pod names
$promPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}'
$grafanaPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}'
$lokiPod = kubectl get pods -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].metadata.name}'
$argocdPod = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}'

# Start port-forwards
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring pod/$promPod 9090:9090"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring pod/$grafanaPod 3001:80"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring pod/$lokiPod 3100:3100"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n argocd pod/$argocdPod 8080:8080"
```

---

## 📈 What to Monitor

### In Grafana:
1. **Kubernetes Cluster Metrics**
   - Node CPU/Memory usage
   - Pod resource consumption
   - Network I/O

2. **Application Metrics**
   - Request rates per service
   - Response times
   - Error rates
   - Database connection pools

3. **Business Metrics** (if configured)
   - Ride bookings per hour
   - Active users
   - Payment success rates

### In Prometheus:
- Query specific metrics
- Set up alerting rules
- Check service discovery status
- View scrape targets

### In ArgoCD:
- Application deployment status
- Git repository sync status
- Resource health
- Sync history

---

## 🔍 Troubleshooting

### Port-forward not working?
1. Check if the pod is running:
   ```powershell
   kubectl get pods -n monitoring
   kubectl get pods -n argocd
   ```

2. Verify port-forward is active:
   ```powershell
   Get-NetTCPConnection -LocalPort 3001,9090,3100,8080
   ```

3. Restart port-forward:
   ```powershell
   # Kill existing
   Get-Process kubectl | Stop-Process
   # Restart using commands above
   ```

### Can't access Grafana?
- Check if Grafana pod is ready: `kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana`
- Verify port-forward: `Get-NetTCPConnection -LocalPort 3001`
- Check Grafana logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`

### Forgot credentials?
- Grafana: `kubectl get secret -n monitoring prometheus-grafana -o yaml`
- ArgoCD: `kubectl -n argocd get secret argocd-initial-admin-secret -o yaml`

---

## 📝 Notes

- Keep port-forward windows open to maintain access
- All dashboards are accessible only via port-forward (not exposed via LoadBalancer)
- For production, consider using Ingress or LoadBalancer services
- Monitoring data is stored in persistent volumes (if configured)


