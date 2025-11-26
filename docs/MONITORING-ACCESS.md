# 📊 Monitoring & GitOps Access Guide

## ✅ **All Services Installed & Port-Forwarded!**

---

## 🔗 **Access URLs**

### **1. Grafana Dashboard** 📈
- **URL:** http://localhost:3001
- **Username:** `admin`
- **Password:** `MXIcFbtl4xTlHHGx7JEmwW8PfNrjzoGGfQfVr7vo`
- **Features:**
  - Visualize metrics from Prometheus
  - Pre-configured Kubernetes dashboards
  - Custom dashboards for ride-booking services
  - Import dashboard: `monitoring/grafana/dashboards/ride-booking-dashboard.json`

### **2. Prometheus UI** 🔍
- **URL:** http://localhost:9090
- **Authentication:** None required
- **Features:**
  - Query metrics using PromQL
  - View targets and service discovery
  - Check alerting rules
  - Explore time-series data

### **3. ArgoCD (GitOps)** 🔄
- **URL:** https://localhost:8080
- **Username:** `admin`
- **Password:** `vNmSMFhjt54xyUif`
- **Features:**
  - View deployed applications
  - Monitor sync status
  - Manage GitOps workflows
  - Application health and status

---

## 🚀 **Port-Forward Status**

All port-forwards are running in separate PowerShell windows:

| Service | Port | Status |
|---------|------|--------|
| Grafana | 3001 | ✅ Running |
| Prometheus | 9090 | ✅ Running |
| ArgoCD | 8080 | ✅ Running |

---

## 📝 **Quick Commands**

### **Get Grafana Password:**
```powershell
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### **Get ArgoCD Password:**
```powershell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

### **Restart Port-Forwards:**
```powershell
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80

# Prometheus (find service first)
kubectl get svc -n monitoring
kubectl port-forward -n monitoring svc/<prometheus-service> 9090:9090

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

---

## 📊 **What to Monitor**

### **In Grafana:**
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

### **In Prometheus:**
- Query specific metrics
- Set up alerting rules
- Check service discovery status
- View scrape targets

### **In ArgoCD:**
- Application deployment status
- Git repository sync status
- Resource health
- Sync history

---

## 🔍 **Troubleshooting**

### **Port-forward not working?**
1. Check if pods are running:
   ```powershell
   kubectl get pods -n monitoring
   kubectl get pods -n argocd
   ```

2. Verify port-forward is active:
   ```powershell
   netstat -ano | findstr "3001 9090 8080"
   ```

3. Restart port-forward:
   - Close the PowerShell window
   - Run the port-forward command again

### **Can't access Grafana?**
- Check if port 3001 is already in use
- Verify Grafana pod is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana`
- Check logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`

### **Can't access Prometheus?**
- Check if port 9090 is already in use
- Find Prometheus service: `kubectl get svc -n monitoring`
- Check logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus`

### **Can't access ArgoCD?**
- Use **https://** (not http://)
- Accept the self-signed certificate warning
- Check if port 8080 is already in use
- Verify ArgoCD pod is running: `kubectl get pods -n argocd`

---

## 🎯 **Next Steps**

1. **Import Grafana Dashboard:**
   - Login to Grafana
   - Go to Dashboards → Import
   - Upload: `monitoring/grafana/dashboards/ride-booking-dashboard.json`

2. **Configure Prometheus Data Source in Grafana:**
   - Already configured automatically by Helm chart
   - Verify: Configuration → Data Sources → Prometheus

3. **Set Up ArgoCD Applications:**
   - Login to ArgoCD
   - Deploy applications: `kubectl apply -f gitops/argocd-apps.yaml`

---

## ✅ **All Set!**

You can now access:
- 📊 **Grafana:** http://localhost:3001
- 🔍 **Prometheus:** http://localhost:9090
- 🔄 **ArgoCD:** https://localhost:8080

Enjoy monitoring your ride-booking platform! 🚀

