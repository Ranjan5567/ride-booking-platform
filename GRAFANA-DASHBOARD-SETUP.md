# 📊 Grafana Dashboard Setup Guide

## 🎯 **Quick Setup Steps**

### **Step 1: Import Dashboard**

1. **Login to Grafana:**
   - URL: http://localhost:3001
   - Username: `admin`
   - Password: `MXIcFbtl4xTlHHGx7JEmwW8PfNrjzoGGfQfVr7vo`

2. **Import Dashboard:**
   - Click **"+"** icon (top left) → **"Import"**
   - Click **"Upload JSON file"**
   - Select: `monitoring/grafana/dashboards/ride-booking-complete-dashboard.json`
   - Click **"Load"**
   - Click **"Import"**

---

## 📈 **Manual Dashboard Creation Steps**

If you want to create dashboards manually, follow these steps:

### **1. Create New Dashboard**

1. Click **"+"** → **"Create"** → **"Dashboard"**
2. Click **"Add visualization"**
3. Select **"Prometheus"** as data source

---

### **2. Panel Queries for Ride Count**

#### **Panel: Total Rides Created**
- **Title:** "Ride Count - Total Rides"
- **Query:**
  ```promql
  sum(increase(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[1h]))
  ```
- **Legend:** `Total Rides`
- **Unit:** Short

#### **Panel: Rides Per Minute**
- **Title:** "Rides Created Per Minute"
- **Query:**
  ```promql
  rate(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[1m]) * 60
  ```
- **Legend:** `Rides/min`
- **Unit:** Short

#### **Panel: Rides Over Time**
- **Title:** "Ride Creation Rate"
- **Query:**
  ```promql
  increase(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[5m])
  ```
- **Legend:** `Rides (5min window)`
- **Unit:** Short

---

### **3. Panel Queries for All Services**

#### **Panel: All Services - Pod Count**
- **Title:** "All Services - Pod Count"
- **Query:**
  ```promql
  kube_deployment_status_replicas{deployment=~"ride-service|user-service|driver-service|payment-service"}
  ```
- **Legend:** `{{deployment}}`
- **Unit:** Short

#### **Panel: All Services - CPU Usage**
- **Title:** "All Services - CPU Usage"
- **Query:**
  ```promql
  rate(container_cpu_usage_seconds_total{pod=~"ride-service.*|user-service.*|driver-service.*|payment-service.*", container!="POD"}[5m]) * 100
  ```
- **Legend:** `{{pod}}`
- **Unit:** Percent (0-100)

#### **Panel: All Services - Memory Usage**
- **Title:** "All Services - Memory Usage"
- **Query:**
  ```promql
  container_memory_working_set_bytes{pod=~"ride-service.*|user-service.*|driver-service.*|payment-service.*", container!="POD"} / 1024 / 1024
  ```
- **Legend:** `{{pod}}`
- **Unit:** Megabytes

#### **Panel: All Services - Request Rate**
- **Title:** "All Services - Request Rate"
- **Query:**
  ```promql
  sum(rate(http_requests_total{service=~"ride-service|user-service|driver-service|payment-service"}[5m])) by (service)
  ```
- **Legend:** `{{service}}`
- **Unit:** Requests/sec

#### **Panel: All Services - Error Rate**
- **Title:** "All Services - Error Rate"
- **Query 1 (5xx Errors):**
  ```promql
  sum(rate(http_requests_total{service=~"ride-service|user-service|driver-service|payment-service", status=~"5.."}[5m])) by (service)
  ```
- **Legend:** `{{service}} - 5xx`
- **Query 2 (4xx Errors):**
  ```promql
  sum(rate(http_requests_total{service=~"ride-service|user-service|driver-service|payment-service", status=~"4.."}[5m])) by (service)
  ```
- **Legend:** `{{service}} - 4xx`
- **Unit:** Errors/sec

---

### **4. Panel Queries for Ride Service (HPA Monitoring)**

#### **Panel: Ride Service - Pod Count (HPA)**
- **Title:** "Ride Service - Pod Count (HPA)"
- **Query 1 (Current Replicas):**
  ```promql
  kube_deployment_status_replicas{deployment="ride-service"}
  ```
- **Legend:** `Current Replicas`
- **Query 2 (Desired Replicas):**
  ```promql
  kube_deployment_spec_replicas{deployment="ride-service"}
  ```
- **Legend:** `Desired Replicas`
- **Unit:** Short

#### **Panel: Ride Service - CPU Usage**
- **Title:** "Ride Service - CPU Usage"
- **Query:**
  ```promql
  rate(container_cpu_usage_seconds_total{pod=~"ride-service.*", container!="POD"}[5m]) * 100
  ```
- **Legend:** `{{pod}}`
- **Unit:** Percent (0-100)

#### **Panel: Ride Service - Memory Usage**
- **Title:** "Ride Service - Memory Usage"
- **Query:**
  ```promql
  container_memory_working_set_bytes{pod=~"ride-service.*", container!="POD"} / 1024 / 1024
  ```
- **Legend:** `{{pod}}`
- **Unit:** Megabytes

---

## 🔍 **Useful Prometheus Queries**

### **Ride Count Queries:**
```promql
# Total rides created (last hour)
sum(increase(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[1h]))

# Rides per minute
rate(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[1m]) * 60

# Rides created in last 24 hours
sum(increase(http_requests_total{service="ride-service", method="POST", path=~"/ride.*"}[24h]))
```

### **Service Health Queries:**
```promql
# All services pod count
kube_deployment_status_replicas{deployment=~"ride-service|user-service|driver-service|payment-service"}

# All services CPU usage
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*|user-service.*|driver-service.*|payment-service.*", container!="POD"}[5m]) * 100

# All services memory usage
container_memory_working_set_bytes{pod=~"ride-service.*|user-service.*|driver-service.*|payment-service.*", container!="POD"} / 1024 / 1024
```

### **Request Metrics:**
```promql
# Request rate per service
sum(rate(http_requests_total{service=~"ride-service|user-service|driver-service|payment-service"}[5m])) by (service)

# Error rate per service
sum(rate(http_requests_total{service=~"ride-service|user-service|driver-service|payment-service", status=~"5.."}[5m])) by (service)

# Response time (p95)
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="ride-service"}[5m])) by (le, service))
```

---

## 📝 **Dashboard Configuration Tips**

1. **Set Refresh Interval:**
   - Click dashboard settings (gear icon)
   - Set "Time range" to "Last 1 hour"
   - Set "Auto-refresh" to "30s"

2. **Panel Settings:**
   - Right-click panel → "Edit"
   - Configure:
     - **Title:** Descriptive name
     - **Unit:** Appropriate unit (short, percent, bytes, etc.)
     - **Legend:** Show legend with meaningful labels
     - **Thresholds:** Add warning/critical thresholds

3. **Variables (Optional):**
   - Create variables for service selection
   - Settings → Variables → New
   - Name: `service`
   - Type: Query
   - Query: `label_values(kube_deployment_status_replicas, deployment)`

---

## ✅ **Expected Dashboard Panels**

After importing or creating, you should have:

1. ✅ **Ride Service - Pod Count (HPA)**
2. ✅ **All Services - Pod Count**
3. ✅ **Ride Service - CPU Usage**
4. ✅ **Ride Service - Memory Usage**
5. ✅ **All Services - Request Rate**
6. ✅ **All Services - Error Rate**
7. ✅ **Ride Count - Total Rides Created**
8. ✅ **Ride Service - Response Time (p95)**
9. ✅ **All Services - CPU Usage**
10. ✅ **All Services - Memory Usage**

---

## 🔧 **Troubleshooting**

### **No Data Showing?**
1. Check if Prometheus is scraping metrics:
   - Go to Prometheus: http://localhost:9090
   - Go to "Status" → "Targets"
   - Verify all targets are "UP"

2. Check if services expose metrics:
   ```powershell
   kubectl get pods -l app=ride-service
   kubectl logs <pod-name> | Select-String "metrics"
   ```

3. Verify query in Prometheus:
   - Go to Prometheus: http://localhost:9090
   - Go to "Graph"
   - Paste your query
   - Check if data appears

### **Query Not Working?**
- Check metric names in Prometheus:
  - Go to Prometheus: http://localhost:9090
  - Go to "Graph"
  - Type metric name (e.g., `http_requests_total`)
  - Check available labels

---

## 🎉 **Done!**

Your Grafana dashboard should now show:
- ✅ Ride counts
- ✅ All services metrics
- ✅ HPA pod scaling
- ✅ CPU/Memory usage
- ✅ Request/Error rates

**Refresh your browser to see the data!** 📊

