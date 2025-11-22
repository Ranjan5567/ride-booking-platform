# 🔍 GCP Analytics Pipeline - Issues Found

## ❌ **CRITICAL ISSUES DISCOVERED**

### **Issue 1: Analytics Script NOT Running** ❌
- **Status:** Script is not running on Dataproc cluster
- **Evidence:** `ps aux | grep analytics` returns no process
- **Impact:** No messages are being consumed from Pub/Sub, no data written to Firestore

### **Issue 2: Missing Python Dependencies** ❌
- **Error:** `ModuleNotFoundError: No module named 'google'`
- **Location:** `/tmp/analytics.log` on Dataproc master node
- **Root Cause:** Google Cloud libraries (`google-cloud-pubsub`, `google-cloud-firestore`) are not installed
- **Attempted Fix:** Tried `pip install --break-system-packages` but cluster has **no internet access**

### **Issue 3: Network Connectivity** ❌
- **Problem:** Dataproc cluster cannot reach PyPI to install packages
- **Error:** `Network is unreachable` when trying to install via pip
- **Impact:** Cannot install required Python packages

---

## ✅ **What IS Working**

### **1. Pub/Sub Publishing** ✅
- **Status:** Working perfectly
- **Evidence:** Found 3 messages in subscription `ride-booking-rides-flink`:
  ```
  - Ride ID 5: Test Location → Test Destination (Mumbai)
  - Ride ID 4: Andheri, Mumbai → Bandra, Mumbai (Mumbai)
  - Ride ID 2: Test Location A → Test Location B (Mumbai)
  ```
- **Conclusion:** `ride-service` is successfully publishing messages to Pub/Sub

### **2. Dataproc Cluster** ✅
- **Status:** RUNNING
- **Cluster:** `ride-booking-flink-cluster`
- **Master:** `ride-booking-flink-cluster-m` (zone: asia-south1-b)
- **Workers:** 2 workers running
- **Conclusion:** Infrastructure is healthy

### **3. Firestore Database** ✅
- **Status:** Created and ready
- **Database:** `ride-booking-analytics`
- **Location:** asia-south1
- **Conclusion:** Database exists but is empty (no data being written)

---

## 🔧 **ROOT CAUSE ANALYSIS**

### **The Problem Chain:**
```
1. Dataproc cluster has NO internet access
   ↓
2. Cannot install Python packages via pip
   ↓
3. Analytics script fails on import: `ModuleNotFoundError: No module named 'google'`
   ↓
4. Script never starts running
   ↓
5. Pub/Sub messages accumulate (not consumed)
   ↓
6. Firestore remains empty (no data written)
```

### **Why This Happened:**
- The cluster was created **without** initialization actions to install Python packages
- The cluster has **no external IP** or **NAT gateway** for internet access
- The `install_and_run.sh` script was run manually but failed due to network issues

---

## 🎯 **SOLUTION OPTIONS**

### **Option 1: Add Initialization Action (RECOMMENDED)** ✅
**Best for:** Long-term solution, proper infrastructure setup

**Steps:**
1. Create initialization script that installs packages
2. Upload script to GCS bucket
3. Recreate Dataproc cluster with initialization action
4. Script will install packages during cluster startup

**Pros:**
- Automatic package installation
- Works even without internet access (if using GCS)
- Proper infrastructure-as-code approach

**Cons:**
- Requires cluster recreation
- Takes ~5-10 minutes

---

### **Option 2: Add NAT Gateway** ✅
**Best for:** Quick fix, allows internet access

**Steps:**
1. Create Cloud NAT gateway
2. Configure cluster subnet to use NAT
3. Install packages via pip
4. Start analytics script

**Pros:**
- Quick to implement
- Allows future package installations
- No cluster recreation needed

**Cons:**
- Additional infrastructure cost
- Security consideration (outbound internet access)

---

### **Option 3: Use Pre-installed Packages** ✅
**Best for:** If Dataproc image has packages

**Steps:**
1. Check if packages are in different Python environment
2. Use conda or system Python if available
3. Modify script to use correct Python path

**Pros:**
- No installation needed
- Fastest solution

**Cons:**
- May not have required packages
- Less flexible

---

### **Option 4: Manual Package Installation via GCS** ✅
**Best for:** Quick fix without cluster recreation

**Steps:**
1. Download Python wheels (.whl files) locally
2. Upload to GCS bucket
3. Install from GCS on cluster
4. Start analytics script

**Pros:**
- No cluster recreation
- No internet needed on cluster
- Works immediately

**Cons:**
- Manual process
- Need to handle dependencies

---

## 📊 **CURRENT STATE SUMMARY**

| Component | Status | Details |
|-----------|--------|---------|
| **Pub/Sub Topic** | ✅ Working | Messages being published |
| **Pub/Sub Subscription** | ✅ Working | 3 messages waiting |
| **Dataproc Cluster** | ✅ Running | Healthy, 1 master + 2 workers |
| **Analytics Script** | ❌ **NOT RUNNING** | Failed due to missing packages |
| **Firestore Database** | ✅ Ready | Empty (no data written) |
| **Network Access** | ❌ **NO INTERNET** | Cannot install packages |

---

## 🚀 **RECOMMENDED FIX (Option 1 - Initialization Action)**

### **Step 1: Create Initialization Script**
```bash
#!/bin/bash
# Install Python packages for analytics
python3 -m pip install --user --upgrade \
    google-cloud-pubsub \
    google-cloud-firestore
```

### **Step 2: Upload to GCS**
```bash
gsutil cp install_packages.sh gs://careful-cosine-478715-a0-dataproc-staging-*/init-scripts/
```

### **Step 3: Update Terraform**
Add initialization action to `infra/gcp/modules/dataproc/main.tf`:
```hcl
initialization_action {
  script      = "gs://bucket/init-scripts/install_packages.sh"
  timeout_sec = 300
}
```

### **Step 4: Recreate Cluster**
```bash
cd infra/gcp
terraform apply
```

---

## 📝 **IMMEDIATE ACTION ITEMS**

1. ✅ **Verify:** Pub/Sub has messages (DONE - 3 messages found)
2. ❌ **Fix:** Install Python packages on cluster
3. ❌ **Fix:** Start analytics script
4. ❌ **Verify:** Messages being consumed
5. ❌ **Verify:** Data appearing in Firestore

---

## 🔍 **VERIFICATION COMMANDS**

### **Check if script is running:**
```bash
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b \
  --command="ps aux | grep ride_analytics"
```

### **Check Pub/Sub messages:**
```bash
gcloud pubsub subscriptions pull ride-booking-rides-flink --limit=5
```

### **Check Firestore data:**
```bash
# Use Firestore console or gcloud commands
```

### **Check analytics logs:**
```bash
gcloud compute ssh ride-booking-flink-cluster-m --zone=asia-south1-b \
  --command="tail -50 /tmp/analytics.log"
```

---

## 🎯 **EXPECTED BEHAVIOR AFTER FIX**

1. ✅ Analytics script running as background process
2. ✅ Pub/Sub messages being consumed (subscription count decreasing)
3. ✅ Data appearing in Firestore `ride_analytics` collection
4. ✅ Analytics dashboard showing real-time data
5. ✅ Pub/Sub results topic receiving aggregated data

---

**Status:** 🔴 **ANALYTICS PIPELINE IS BROKEN - NEEDS FIX**

