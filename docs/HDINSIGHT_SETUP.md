# 🔥 Azure HDInsight + Flink Setup Guide

Complete guide for deploying and using Azure HDInsight with Apache Flink for real-time stream processing.

---

## 📋 **Table of Contents**

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Deployment](#deployment)
5. [Flink Installation](#flink-installation)
6. [Job Submission](#job-submission)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 **Overview**

Azure HDInsight provides a managed Hadoop cluster that we use to run Apache Flink for real-time stream processing. This setup:

- ✅ Meets academic requirements for managed cluster computing
- ✅ Processes ride events from Azure Event Hub
- ✅ Aggregates data in real-time (rides per city per minute)
- ✅ Stores results in Azure Cosmos DB
- ✅ Provides Flink Web UI for monitoring
- ✅ Fully managed and scalable

---

## 🏗️ **Architecture**

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Ride Service   │────▶│  Azure Event Hub │────▶│   HDInsight     │
│   (EKS Pod)     │     │  (Kafka-compat)  │     │  + Flink Job    │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                            │
                                                            ▼
                                                   ┌─────────────────┐
                                                   │  Cosmos DB      │
                                                   │  (Analytics)    │
                                                   └─────────────────┘
```

**Flow:**
1. Ride Service publishes ride events to Event Hub (Kafka topic: `rides`)
2. Flink job consumes events from Event Hub
3. Flink aggregates rides per city per minute
4. Results stored in Cosmos DB for analytics dashboard

---

## ✅ **Prerequisites**

Ensure you have:
- [x] Azure CLI installed and logged in
- [x] SSH client (Windows: PuTTY or OpenSSH)
- [x] Maven/Java for building Flink job
- [x] Azure subscription with HDInsight quota
- [x] Terraform deployment completed

---

## 🚀 **Deployment**

### **Step 1: Deploy Infrastructure**

```bash
cd infra/azure
terraform init
terraform apply -auto-approve
```

**⏱️ Deployment Time:** ~30-35 minutes

Resources created:
- ✅ HDInsight Hadoop Cluster (3.1)
  - 2x Head Nodes (Standard_D3_v2)
  - 2x Worker Nodes (Standard_D3_v2)
  - 3x Zookeeper Nodes (Standard_A2_v2)
- ✅ Storage Account for HDInsight
- ✅ Virtual Network + Subnet
- ✅ Azure Event Hub
- ✅ Cosmos DB Account

### **Step 2: Get Cluster Credentials**

```powershell
# Get SSH endpoint
$sshEndpoint = terraform output -raw hdinsight_ssh_endpoint

# Get HTTPS endpoint
$httpsEndpoint = terraform output -raw hdinsight_cluster_endpoint

# Default credentials (from variables)
# Username: sshuser
# Password: P@ssw0rd123!
```

---

## 🔥 **Flink Installation**

### **Option A: Using PowerShell Script (Recommended)**

```powershell
cd scripts
.\deploy-flink-hdinsight.ps1
```

This script will:
1. ✅ Build the Flink job JAR
2. ✅ Get HDInsight SSH endpoint
3. ✅ Provide step-by-step manual instructions
4. ✅ Export connection strings

### **Option B: Manual Installation**

#### **1. SSH into HDInsight Cluster**

```bash
ssh sshuser@<cluster-name>-ssh.azurehdinsight.net
# Password: P@ssw0rd123!
```

#### **2. Download and Install Flink**

```bash
cd /home/sshuser

# Download Flink 1.17.1
wget https://archive.apache.org/dist/flink/flink-1.17.1/flink-1.17.1-bin-scala_2.12.tgz

# Extract
tar -xzf flink-1.17.1-bin-scala_2.12.tgz
cd flink-1.17.1

# Start Flink cluster
./bin/start-cluster.sh

# Verify Flink is running
./bin/flink list
```

#### **3. Configure Flink (Optional)**

Edit `conf/flink-conf.yaml` if needed:

```yaml
# Increase taskmanager memory for larger workloads
taskmanager.memory.process.size: 2048m

# Set parallelism
parallelism.default: 2
```

---

## 📤 **Job Submission**

### **Step 1: Build Flink Job**

On your **local machine**:

```bash
cd analytics/flink-job
mvn clean package

# JAR location: target/ride-analytics-1.0.jar
```

### **Step 2: Upload JAR to HDInsight**

```bash
# Get SSH endpoint from Terraform
cd ../../infra/azure
$sshEndpoint = terraform output -raw hdinsight_ssh_endpoint

# Upload JAR
scp ../analytics/flink-job/target/ride-analytics-1.0.jar \
    sshuser@$sshEndpoint:/home/sshuser/flink-1.17.1/
```

### **Step 3: Get Connection Strings**

```powershell
cd infra/azure

# Event Hub connection string
$eventhubConn = terraform output -raw eventhub_connection_string

# Cosmos DB connection string
$cosmosdbConn = terraform output -raw cosmosdb_connection_string

Write-Output "EventHub: $eventhubConn"
Write-Output "CosmosDB: $cosmosdbConn"
```

### **Step 4: Submit Job**

SSH into HDInsight and run:

```bash
cd /home/sshuser/flink-1.17.1

# Set environment variables
export EVENTHUB_CONNECTION_STRING="<your-eventhub-connection-string>"
export COSMOSDB_CONNECTION_STRING="<your-cosmosdb-connection-string>"

# Submit job
./bin/flink run \
  -c com.ridebooking.RideAnalyticsJob \
  ride-analytics-1.0.jar \
  --eventhub-connection-string "$EVENTHUB_CONNECTION_STRING" \
  --cosmosdb-connection-string "$COSMOSDB_CONNECTION_STRING"

# Verify job is running
./bin/flink list
```

**Expected Output:**

```
Submitting Job with JobID: abc123def456...
Job has been submitted with JobID abc123def456
```

---

## 📊 **Monitoring**

### **Flink Web UI**

Access Flink dashboard via SSH tunnel:

```bash
# Create SSH tunnel (port 8081)
ssh -L 8081:localhost:8081 sshuser@<ssh-endpoint>

# Open in browser
http://localhost:8081
```

**Dashboard shows:**
- ✅ Running jobs
- ✅ Task metrics
- ✅ Throughput
- ✅ Checkpoints
- ✅ Back pressure

### **HDInsight Ambari UI**

Access cluster management UI:

```
https://<cluster-name>.azurehdinsight.net
# Username: admin
# Password: P@ssw0rd123!
```

### **Check Job Logs**

```bash
# SSH into HDInsight
ssh sshuser@<ssh-endpoint>

# View Flink logs
cd /home/sshuser/flink-1.17.1/log
tail -f flink-*-jobmanager-*.log
tail -f flink-*-taskmanager-*.log
```

### **Verify Data Flow**

1. **Check Event Hub messages:**
   ```bash
   # Should see ride events coming in
   ```

2. **Check Cosmos DB:**
   ```bash
   # Query Cosmos DB for aggregated data
   az cosmosdb sql container query \
     --resource-group cloudProject \
     --account-name ride-booking-cosmosdb \
     --database-name analytics \
     --container-name ride_analytics \
     --query "SELECT * FROM c"
   ```

---

## 🐛 **Troubleshooting**

### **Issue: Flink cluster won't start**

```bash
# Check if ports are available
netstat -tuln | grep -E '8081|6123'

# Kill existing Flink processes
./bin/stop-cluster.sh
pkill -f flink

# Restart
./bin/start-cluster.sh
```

### **Issue: Job submission fails**

```bash
# Check Flink logs
tail -f log/flink-*-jobmanager-*.log

# Common issues:
# 1. Missing dependencies in JAR
# 2. Wrong connection strings
# 3. Kafka/Event Hub connectivity
```

### **Issue: No data in Cosmos DB**

1. **Check Event Hub has messages:**
   ```bash
   # Use Azure Portal > Event Hub > Metrics
   ```

2. **Check Flink job is consuming:**
   ```bash
   # Flink Web UI > Jobs > Your Job > Metrics
   # Check "records-consumed-rate"
   ```

3. **Check Cosmos DB connection:**
   ```bash
   # Verify connection string is correct
   # Check Cosmos DB firewall rules (allow HDInsight subnet)
   ```

### **Issue: High latency/slow processing**

1. **Increase parallelism:**
   ```bash
   # Edit conf/flink-conf.yaml
   parallelism.default: 4
   
   # Restart cluster
   ./bin/stop-cluster.sh
   ./bin/start-cluster.sh
   ```

2. **Scale HDInsight:**
   ```bash
   # Azure Portal > HDInsight > Scale cluster
   # Add more worker nodes
   ```

### **Issue: Can't access Flink Web UI**

```bash
# Verify SSH tunnel is active
ssh -L 8081:localhost:8081 sshuser@<ssh-endpoint>

# Try different port if 8081 is busy
ssh -L 9999:localhost:8081 sshuser@<ssh-endpoint>
# Then access: http://localhost:9999
```

---

## 🎯 **Demo Checklist**

For your project demonstration:

- [ ] HDInsight cluster is running
- [ ] Flink job is submitted and active
- [ ] Event Hub is receiving ride events
- [ ] Cosmos DB is being populated
- [ ] Flink Web UI is accessible
- [ ] Real-time aggregation is working
- [ ] Frontend analytics dashboard shows data

---

## 📚 **Additional Resources**

- [Azure HDInsight Documentation](https://docs.microsoft.com/en-us/azure/hdinsight/)
- [Apache Flink Documentation](https://flink.apache.org/)
- [Event Hub Kafka Integration](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-for-kafka-ecosystem-overview)
- [Cosmos DB SQL API](https://docs.microsoft.com/en-us/azure/cosmos-db/sql-query-getting-started)

---

## 💡 **Pro Tips**

1. **Use Flink savepoints** before redeploying jobs
2. **Monitor Event Hub lag** to ensure Flink keeps up
3. **Set up auto-scaling** for HDInsight based on load
4. **Use Cosmos DB partition keys** effectively (city field)
5. **Keep Flink version consistent** with job dependencies

---

**Need Help?** Check the troubleshooting section or review Flink logs!

