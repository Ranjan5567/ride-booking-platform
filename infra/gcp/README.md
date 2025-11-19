# GCP Infrastructure (Cloud Provider B)

This directory contains Terraform configuration for deploying GCP infrastructure as **Cloud Provider B** for the Ride Booking Platform.

## Architecture

- **Dataproc Cluster**: Managed Hadoop/Spark cluster with Flink installed via initialization script
- **Firestore**: NoSQL database for storing analytics results
- **Confluent Cloud Kafka**: Managed Kafka service (configured externally, credentials provided via variables)

## Prerequisites

1. **GCP Account Setup**:
   ```bash
   # Install gcloud CLI
   # https://cloud.google.com/sdk/docs/install
   
   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   
   # Set project
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Enable Required APIs**:
   ```bash
   gcloud services enable dataproc.googleapis.com
   gcloud services enable firestore.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable storage-api.googleapis.com
   ```

3. **Confluent Cloud Setup**:
   - Sign up at https://confluent.cloud
   - Create a Kafka cluster
   - Create API keys
   - Create topics: `rides` and `ride-results`

## Configuration

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   ```hcl
   gcp_project_id = "your-gcp-project-id"
   gcp_region     = "us-central1"
   gcp_zone       = "us-central1-a"
   
   # Confluent Cloud Kafka
   kafka_bootstrap_servers = "pkc-xxxxx.region.provider.confluent.cloud:9092"
   kafka_api_key           = "your-api-key"
   kafka_api_secret        = "your-api-secret"
   ```

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

## Outputs

After deployment, get the outputs:

```bash
# Cluster name
terraform output dataproc_cluster_name

# Firestore database ID
terraform output firestore_database_id
```

## Flink Job Deployment

After the Dataproc cluster is created:

1. **SSH to master node**:
   ```bash
   CLUSTER_NAME=$(terraform output -raw dataproc_cluster_name)
   REGION=$(terraform output -raw gcp_region)
   
   gcloud dataproc clusters ssh $CLUSTER_NAME \
     --region=$REGION \
     --zone=$(terraform output -raw gcp_zone)
   ```

2. **Start Flink cluster**:
   ```bash
   /opt/flink/bin/start-cluster.sh
   ```

3. **Submit Flink job**:
   ```bash
   # Upload your Flink JAR to GCS first
   gsutil cp analytics/flink-job/target/ride-analytics-job.jar gs://your-bucket/
   
   # Submit job
   /opt/flink/bin/flink run \
     -c com.ridebooking.RideAnalyticsJob \
     gs://your-bucket/ride-analytics-job.jar
   ```

4. **Access Flink Web UI**:
   ```bash
   # Create SSH tunnel
   gcloud compute ssh $CLUSTER_NAME-m \
     --zone=$(terraform output -raw gcp_zone) \
     -- -L 8081:localhost:8081 -N
   
   # Open http://localhost:8081
   ```

## Requirements Met

✅ **Requirement (e)**: Real-time stream processing service (Flink) running on managed cluster (Google Dataproc)  
✅ **Requirement (f)**: Managed Kafka service (Confluent Cloud)  
✅ **Requirement (f)**: NoSQL database (Firestore) for analytics results  
✅ **Requirement (a)**: All infrastructure provisioned via Terraform (IaC)

## Cleanup

```bash
terraform destroy
```

**Note**: This will delete the Dataproc cluster and Firestore database. Make sure to backup any important data first.

