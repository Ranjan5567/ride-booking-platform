# 🗑️ Files to Delete - Cleanup Guide

## ✅ **SAFE TO DELETE** (Unnecessary Files)

### **1. Duplicate ArgoCD Configuration Files** (Keep only `argocd-apps.yaml`)
```
gitops/argocd-apps-local.yaml          ❌ DELETE (temporary fix file)
gitops/argocd-apps-direct.yaml         ❌ DELETE (temporary fix file)
gitops/argocd-apps-local-direct.yaml   ❌ DELETE (temporary fix file)
```
**Keep:** `gitops/argocd-apps.yaml` (main file)

---

### **2. Duplicate Grafana Dashboard** (Keep only the complete one)
```
monitoring/grafana/dashboards/ride-booking-dashboard.json  ❌ DELETE (old/simple version)
```
**Keep:** `monitoring/grafana/dashboards/ride-booking-complete-dashboard.json` (complete version)

---

### **3. Duplicate Documentation Files**
```
MONITORING_ACCESS.md          ❌ DELETE (duplicate, underscore version)
GRAFANA_DASHBOARD_SETUP.md   ❌ DELETE (duplicate, underscore version)
```
**Keep:** `MONITORING-ACCESS.md` and `GRAFANA-DASHBOARD-SETUP.md` (hyphen versions, more recent)

---

### **4. Temporary Fix Documentation** (Optional - can delete if not needed)
These are all temporary fix docs created during troubleshooting. You can delete them if you don't need the history:
```
ANALYTICS-PAGE-FIX.md         ❌ DELETE (temporary fix doc)
API-FIX-SUMMARY.md            ❌ DELETE (temporary fix doc)
ARGOCD-FIX.md                 ❌ DELETE (temporary fix doc)
FIRESTORE-FIX-SUMMARY.md      ❌ DELETE (temporary fix doc)
FRONTEND-FIX-COMPLETE.md      ❌ DELETE (temporary fix doc)
```
**Note:** These might be useful for reference, but not essential.

---

### **5. Old/Unused Files**
```
kubectl.exe                   ❌ DELETE (binary shouldn't be in repo)
docker-compose-test.yml       ❌ DELETE (if not using docker-compose)
```
**Note:** `kubectl.exe` is a binary file that shouldn't be in version control.

---

### **6. Temporary/Test Files** (Check if used)
```
scripts/check_firestore.py                    ⚠️ DELETE (temporary test script)
scripts/check-and-restart-analytics.sh         ⚠️ DELETE (if not using)
scripts/restart-analytics-simple.sh            ⚠️ DELETE (if not using)
scripts/restart-analytics.ps1                  ⚠️ DELETE (if not using)
scripts/start-analytics-on-cluster.sh          ⚠️ DELETE (if not using)
```
**Note:** Check if these scripts are still being used before deleting.

---

### **7. Old Analytics Scripts** (If not using)
```
analytics/flink-job/python/ride_analytics.py   ⚠️ DELETE (if using standalone version)
analytics/flink-job/python/run_analytics.sh   ⚠️ DELETE (if not using)
```
**Keep:** `ride_analytics_standalone.py` (the one being used)

---

## 📋 **Summary - Quick Delete List**

### **Definitely Delete:
```
gitops/argocd-apps-local.yaml
gitops/argocd-apps-direct.yaml
gitops/argocd-apps-local-direct.yaml
monitoring/grafana/dashboards/ride-booking-dashboard.json
MONITORING_ACCESS.md
GRAFANA_DASHBOARD_SETUP.md
kubectl.exe
```

### **Optional Delete (Temporary Fix Docs):**
```
ANALYTICS-PAGE-FIX.md
API-FIX-SUMMARY.md
ARGOCD-FIX.md
FIRESTORE-FIX-SUMMARY.md
FRONTEND-FIX-COMPLETE.md
```

### **Check Before Deleting:**
```
scripts/check_firestore.py
scripts/check-and-restart-analytics.sh
scripts/restart-analytics-simple.sh
scripts/restart-analytics.ps1
scripts/start-analytics-on-cluster.sh
analytics/flink-job/python/ride_analytics.py
analytics/flink-job/python/run_analytics.sh
docker-compose-test.yml
```

---

## ✅ **KEEP These Important Files**

### **Essential Documentation:**
- `README.md` - Main project readme
- `DEPLOYMENT.md` - Deployment guide
- `GRAFANA-DASHBOARD-SETUP.md` - Dashboard setup
- `MONITORING-ACCESS.md` - Monitoring access
- `FRONTEND-USER-GUIDE.md` - User guide
- `ARGOCD-OUTOFSYNC-EXPLANATION.md` - Useful explanation

### **Essential Configuration:**
- `gitops/argocd-apps.yaml` - Main ArgoCD config
- `monitoring/grafana/dashboards/ride-booking-complete-dashboard.json` - Complete dashboard
- All service deployment YAMLs in `gitops/`

### **Essential Scripts:**
- `scripts/load-test.ps1` - Load testing
- `scripts/seed-db.ps1` - Database seeding
- `scripts/fix-all-port-forwards.ps1` - Port forwarding
- `scripts/build-and-push-all-services.ps1` - Build script

---

## 🎯 **Recommended Action**

**Delete these 7 files immediately:**
1. `gitops/argocd-apps-local.yaml`
2. `gitops/argocd-apps-direct.yaml`
3. `gitops/argocd-apps-local-direct.yaml`
4. `monitoring/grafana/dashboards/ride-booking-dashboard.json`
5. `MONITORING_ACCESS.md`
6. `GRAFANA_DASHBOARD_SETUP.md`
7. `kubectl.exe`

**Then review and optionally delete the temporary fix docs if you don't need them.**

