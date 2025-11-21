# How to Find and Use Your Ride Booking Dashboard in Grafana

## Step-by-Step Instructions

### Step 1: Access Grafana
1. Open your browser
2. Go to: **http://localhost:3001**
3. Login with:
   - **Username:** `admin`
   - **Password:** `E9ZWkHelLYolVbaxbTIXeDY11JgofWkoV0bM580R`

### Step 2: Find Your Dashboard

#### Option A: Search for "Ride Booking"
1. Click on **"Dashboards"** in the left sidebar (grid icon)
2. In the search bar at the top, type: **"Ride Booking"** or **"ride"**
3. The dashboard should appear in the results

#### Option B: Browse All Dashboards
1. Click on **"Dashboards"** in the left sidebar
2. Click **"Browse"** 
3. Scroll through the list
4. Look for: **"Ride Booking Platform"**

#### Option C: Import Dashboard Manually (If not found)
1. Click the **"+"** icon in the left sidebar
2. Select **"Import dashboard"**
3. Click **"Upload JSON file"**
4. Upload the file: `monitoring/grafana/dashboards/ride-booking-dashboard.json`
5. Click **"Load"**
6. Select **"Prometheus"** as the data source
7. Click **"Import"**

### Step 3: Create a Custom Dashboard (Recommended)

If the dashboard doesn't appear automatically, create one:

1. Click **"+"** in the left sidebar
2. Select **"Create dashboard"**
3. Click **"Add visualization"**
4. Select **"Prometheus"** as data source
5. In the query field, enter:

```
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])
```

6. Click **"Run query"** to see the graph
7. Click the panel title → **"Edit"** to customize
8. Change title to: **"Ride Service CPU Usage"**
9. Click **"Apply"**
10. Click **"Save dashboard"** (top right)
11. Name it: **"Ride Booking Platform"**

### Step 4: Add More Panels

Add these panels to monitor all services:

#### Panel 1: CPU Usage - All Services
**Query:**
```
rate(container_cpu_usage_seconds_total{pod=~"(user|driver|ride|payment)-service.*"}[5m])
```
**Title:** "CPU Usage - All Services"

#### Panel 2: Memory Usage - All Services
**Query:**
```
container_memory_usage_bytes{pod=~"(user|driver|ride|payment)-service.*"}
```
**Title:** "Memory Usage - All Services"

#### Panel 3: Pod Count per Service
**Query:**
```
count(kube_pod_info{pod=~"user-service.*"})
count(kube_pod_info{pod=~"driver-service.*"})
count(kube_pod_info{pod=~"ride-service.*"})
count(kube_pod_info{pod=~"payment-service.*"})
```
**Title:** "Pod Count per Service"

#### Panel 4: Ride Service CPU (Detailed)
**Query:**
```
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])
```
**Title:** "Ride Service CPU Usage"

### Step 5: Verify Prometheus Data Source

1. Go to **"Connections"** → **"Data sources"** (left sidebar)
2. Click on **"Prometheus"**
3. Verify the URL is: `http://prometheus-kube-prometheus-prometheus.monitoring:9090`
4. Click **"Save & test"**
5. Should show: **"Data source is working"**

## Troubleshooting

### Dashboard Not Showing?
1. **Check ConfigMap:**
   ```powershell
   kubectl get configmap -n monitoring | Select-String "ride"
   ```

2. **Recreate Dashboard ConfigMap:**
   ```powershell
   kubectl apply -f gitops/grafana-dashboard-configmap.yaml
   ```

3. **Restart Grafana:**
   ```powershell
   kubectl rollout restart deployment prometheus-grafana -n monitoring
   ```

### No Data in Dashboard?
1. **Check Prometheus Targets:**
   - Go to: http://localhost:9090/targets
   - Verify your services are listed

2. **Check if pods are running:**
   ```powershell
   kubectl get pods -l 'app in (user-service,driver-service,ride-service,payment-service)'
   ```

3. **Test Prometheus query directly:**
   - Go to: http://localhost:9090
   - Click "Graph" tab
   - Enter query: `rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])`
   - Click "Execute"

## Quick Reference: Prometheus Queries

### CPU Usage
```
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])
```

### Memory Usage
```
container_memory_usage_bytes{pod=~"ride-service.*"}
```

### Pod Count
```
count(kube_pod_info{pod=~"ride-service.*"})
```

### All Services CPU
```
rate(container_cpu_usage_seconds_total{pod=~"(user|driver|ride|payment)-service.*"}[5m])
```

### All Services Memory
```
container_memory_usage_bytes{pod=~"(user|driver|ride|payment)-service.*"}
```

