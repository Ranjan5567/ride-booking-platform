# GCP Infrastructure Deployment Guide

## Overview

This directory contains Terraform infrastructure for **Cloud Provider B** (GCP) as required by the BITS Cloud Computing project.

## Architecture Components

### 1. Google Dataproc Cluster
- **Purpose**: Managed Hadoop/Spark cluster running Apache Flink
- **Configuration**:
  - 1 Master node (n1-standard-2)
  - 2 Worker nodes (n1-standard-2)
  - Flink 1.18.1 installed via initialization script
  - Flink Kafka connector pre-installed

### 2. Firestore Database
- **Purpose**: NoSQL database for storing analytics results
- **Type**: Firestore Native mode
- **Location**: us-central (configurable)

### 3. Confluent Cloud Kafka (External)
- **Purpose**: Managed Kafka service for event streaming
- **Note**: Configured externally, credentials provided via Terraform variables
- **Topics Required**: `rides` (input), `ride-results` (output)

## Requirements Compliance

✅ **Requirement (e)**: Real-time stream processing service (Flink) running on managed cluster (Google Dataproc)  
✅ **Requirement (f)**: Managed Kafka service (Confluent Cloud)  
✅ **Requirement (f)**: NoSQL database (Firestore) for analytics results  
✅ **Requirement (a)**: All infrastructure provisioned via Terraform (IaC)

## Prerequisites

1. **GCP Account** with billing enabled
2. **GCP Project** created
3. **gcloud CLI** installed and authenticated
4. **Confluent Cloud** account with Kafka cluster and API keys
5. **Terraform** >= 1.0 installed

## Setup Steps

### Step 1: GCP Authentication

```bash
# Install gcloud CLI (if not installed)
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Enable Required APIs

```bash
gcloud services enable dataproc.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage-api.googleapis.com
```

### Step 3: Confluent Cloud Setup

1. Sign up at https://confluent.cloud
2. Create a Kafka cluster (Basic plan is sufficient for development)
3. Create API keys:
   - Go to API Keys section
   - Create new key
   - Save the API key and secret
4. Create topics:
   - `rides` (input topic for ride events)
   - `ride-results` (output topic for aggregated results)

### Step 4: Configure Terraform

1. Copy the example variables file:
   ```bash
   cd infra/gcp
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars`:
   ```hcl
   gcp_project_id = "your-gcp-project-id"
   gcp_region     = "us-central1"
   gcp_zone       = "us-central1-a"
   
   project_name = "ride-booking"
   
   dataproc_machine_type = "n1-standard-2"
   dataproc_num_workers  = 2
   
   firestore_location = "us-central"
   
   # From Confluent Cloud
   kafka_bootstrap_servers = "pkc-xxxxx.region.provider.confluent.cloud:9092"
   kafka_api_key           = "your-confluent-api-key"
   kafka_api_secret        = "your-confluent-api-secret"
   ```

### Step 5: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply
```

**Expected Output:**
- Dataproc cluster created (~5-10 minutes)
- Firestore database created
- Storage buckets created for staging and scripts

## Post-Deployment

### 1. Get Cluster Information

```bash
# Cluster name
CLUSTER_NAME=$(terraform output -raw dataproc_cluster_name)
REGION=$(terraform output -raw gcp_region)
ZONE=$(terraform output -raw gcp_zone)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
```

### 2. SSH to Master Node

```bash
gcloud dataproc clusters ssh $CLUSTER_NAME \
  --region=$REGION \
  --zone=$ZONE
```

### 3. Start Flink Cluster

Once SSH'd into the master node:

```bash
# Flink should already be installed at /opt/flink
# Start Flink cluster
/opt/flink/bin/start-cluster.sh

# Verify Flink is running
/opt/flink/bin/flink list
```

### 4. Access Flink Web UI

From your local machine:

```bash
# Create SSH tunnel
gcloud compute ssh ${CLUSTER_NAME}-m \
  --zone=$ZONE \
  -- -L 8081:localhost:8081 -N

# Open browser: http://localhost:8081
```

### 5. Submit Flink Job

1. **Build your Flink job** (from project root):
   ```bash
   cd analytics/flink-job
   mvn clean package
   ```

2. **Upload JAR to GCS**:
   ```bash
   # Create a bucket for your job
   gsutil mb gs://your-project-flink-jobs
   
   # Upload JAR
   gsutil cp target/ride-analytics-job.jar gs://your-project-flink-jobs/
   ```

3. **Submit job** (from master node):
   ```bash
   /opt/flink/bin/flink run \
     -c com.ridebooking.RideAnalyticsJob \
     gs://your-project-flink-jobs/ride-analytics-job.jar
   ```

## Verification

### Check Flink Job Status

```bash
# From master node
/opt/flink/bin/flink list

# View job details
/opt/flink/bin/flink info <job-id>
```

### Check Kafka Topics

```bash
# Install kcat (if not installed)
# macOS: brew install kcat
# Linux: apt-get install kafkacat

# Consume from rides topic
kcat -b $KAFKA_BOOTSTRAP \
  -X security.protocol=SASL_SSL \
  -X sasl.mechanism=PLAIN \
  -X sasl.username=$KAFKA_API_KEY \
  -X sasl.password=$KAFKA_API_SECRET \
  -t rides \
  -C

# Consume from ride-results topic
kcat -b $KAFKA_BOOTSTRAP \
  -X security.protocol=SASL_SSL \
  -X sasl.mechanism=PLAIN \
  -X sasl.username=$KAFKA_API_KEY \
  -X sasl.password=$KAFKA_API_SECRET \
  -t ride-results \
  -C
```

### Check Firestore Data

1. Open GCP Console: https://console.cloud.google.com/firestore
2. Select your project
3. Navigate to the `ride_analytics` collection
4. View aggregated data documents

## Troubleshooting

### Dataproc Cluster Creation Fails

- Check quota limits: `gcloud compute project-info describe`
- Verify APIs are enabled
- Check billing is enabled

### Flink Not Starting

- Check Java version: `java -version` (should be Java 11+)
- Check Flink logs: `/opt/flink/log/flink-*-standalonesession-*.log`
- Verify initialization script ran: Check `/var/log/dataproc-startup-script.log`

### Kafka Connection Issues

- Verify Confluent Cloud credentials
- Check network connectivity from Dataproc to Confluent Cloud
- Verify topics exist in Confluent Cloud

### Firestore Access Issues

- Verify Firestore API is enabled
- Check IAM permissions
- Verify database location matches region

## Cost Optimization

- **Dataproc**: Use preemptible workers for cost savings
- **Firestore**: Use pay-as-you-go pricing (no upfront costs)
- **Confluent Cloud**: Use Basic plan for development

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Note: This will delete:
# - Dataproc cluster
# - Firestore database (make sure to backup data first!)
# - Storage buckets
```

## Next Steps

1. Update Flink job code to use Confluent Cloud Kafka configuration
2. Deploy Flink job to Dataproc cluster
3. Configure monitoring and alerting
4. Set up CI/CD for Flink job deployment

