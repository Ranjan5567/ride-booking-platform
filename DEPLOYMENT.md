# Deployment Guide - Ride Booking Platform

Complete step-by-step guide to deploy the multi-cloud ride booking platform for BITS Cloud Computing Project.

---

## Table of Contents

1. [Prerequisites Setup](#phase-1-prerequisites-setup)
2. [Infrastructure Deployment](#phase-2-infrastructure-deployment)
3. [Build and Push Docker Images](#phase-3-build-and-push-docker-images)
4. [Configure Kubernetes](#phase-4-configure-kubernetes-secrets-and-configmaps)
5. [Deploy ArgoCD](#phase-5-deploy-argocd)
6. [Deploy Monitoring Stack](#phase-6-deploy-monitoring-stack)
7. [Deploy Flink Job](#phase-7-deploy-flink-job)
8. [Deploy Frontend](#phase-8-deploy-frontend)
9. [Verify Deployment](#phase-9-verify-deployment)
10. [Manual Testing Guide](#manual-testing-guide)
11. [Troubleshooting](#troubleshooting)

---

## Important Note

⚠️ **Terraform alone will NOT complete the deployment.** 

`terraform apply` only provisions the infrastructure (VPC, EKS, RDS, Lambda, S3, Google Dataproc (Flink), Cloud Pub/Sub, Firestore, etc.). 

You must also:
- Build and push Docker images
- Deploy ArgoCD
- Configure Kubernetes secrets
- Deploy monitoring stack
- Deploy Flink job
- Deploy frontend

---

## Phase 1: Prerequisites Setup

### 1.1 Install Required Tools

Verify all required tools are installed:

```bash
# Check installations
terraform --version   # >= 1.0
aws --version        # AWS CLI v2
gcloud --version     # GCP CLI
kubectl version      # Kubernetes CLI
docker --version     # Docker
helm version         # Helm v3
k6 version           # Load testing tool
node --version       # Node.js 18+ (for frontend)
mvn --version        # Maven (for Flink job)
```

**Installation Links:**
- Terraform: https://www.terraform.io/downloads
- AWS CLI: https://aws.amazon.com/cli/
- GCP CLI: https://cloud.google.com/sdk/docs/install
- kubectl: https://kubernetes.io/docs/tasks/tools/
- Docker: https://docs.docker.com/get-docker/
- Helm: https://helm.sh/docs/intro/install/
- k6: https://k6.io/docs/getting-started/installation/
- Maven: https://maven.apache.org/install.html

### 1.2 Configure Cloud Credentials

#### AWS Configuration
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name: ap-south-1
# - Default output format: json
```

#### GCP Configuration
```bash
gcloud auth login
# Follow browser login flow

# Set your project
gcloud config set project careful-cosine-478715-a0

# Enable required APIs
gcloud services enable dataproc.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com
```

### 1.3 Create Container Registry

Choose one of the following options:

#### Option A: AWS ECR (Recommended for AWS-based deployment)

```bash
# Create repositories for each service
aws ecr create-repository --repository-name user-service --region ap-south-1
aws ecr create-repository --repository-name driver-service --region ap-south-1
aws ecr create-repository --repository-name ride-service --region ap-south-1
aws ecr create-repository --repository-name payment-service --region ap-south-1

# Get ECR login command
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 943812325535.dkr.ecr.ap-south-1.amazonaws.com
```

#### Option B: Docker Hub (Simpler alternative)

```bash
docker login
# Enter your Docker Hub username and password
```

---
## Phase 2: Infrastructure Deployment

### 2.1 Deploy AWS Infrastructure

```bash
cd infra/aws

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars`:**

```hcl
aws_region         = "ap-south-1"
project_name       = "ride-booking"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
db_name            = "ridebooking"
db_username        = "admin"
db_password        = "YourSecurePassword123!"  # ⚠️ CHANGE THIS TO A STRONG PASSWORD
```

**Deploy AWS Infrastructure:**

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (this takes 15-20 minutes)
terraform apply
# Type 'yes' when prompted

# Save important outputs
mkdir -p ../../outputs
terraform output eks_cluster_endpoint > ../../outputs/eks_endpoint.txt
terraform output rds_endpoint > ../../outputs/rds_endpoint.txt
terraform output api_gateway_url > ../../outputs/lambda_url.txt
terraform output s3_bucket_name > ../../outputs/s3_bucket.txt

# Display all outputs
terraform output
```

**✅ Expected Outputs:**
- EKS cluster ID and endpoint
- RDS database endpoint
- Lambda function name
- API Gateway URL
- S3 bucket name

### 2.2 Deploy GCP Infrastructure (Dataproc + Firestore + Pub/Sub)

GCP provides Dataproc (Flink cluster), Firestore (NoSQL), and **Cloud Pub/Sub** (managed pub-sub) for the ride analytics pipeline. Terraform provisions the Pub/Sub topics (`rides`, `ride-results`), the subscription that Flink consumes, and a dedicated service account/key for the AWS ride-service publisher.

**Prerequisites:**
1. Install and authenticate the gcloud CLI:
   ```bash
   gcloud init
   gcloud auth application-default login
   ```
2. Ensure the GCP project `careful-cosine-478715-a0` has billing enabled and Dataproc/Pub/Sub APIs are allowed.

```bash
cd infra/gcp

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars`:**

```hcl
# GCP Configuration
gcp_project_id = "careful-cosine-478715-a0"
gcp_region     = "asia-south1"  # Mumbai, India
gcp_zone       = "asia-south1-a"

# Project Configuration
project_name = "ride-booking"

# Dataproc Configuration
dataproc_machine_type = "n1-standard-2"
dataproc_num_workers  = 2

# Firestore Configuration
firestore_location = "asia-south1"  # Mumbai, India
```

**Deploy GCP Infrastructure:**

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (⏱️ Takes ~10-15 minutes for Dataproc cluster)
terraform apply

# Save important outputs
mkdir -p ../../outputs
terraform output dataproc_cluster_name > ../../outputs/dataproc_cluster.txt
terraform output firestore_database_id > ../../outputs/firestore_db.txt
terraform output pubsub_rides_topic > ../../outputs/pubsub_rides_topic.txt
terraform output pubsub_rides_subscription > ../../outputs/pubsub_rides_subscription.txt
terraform output pubsub_publisher_service_account_email > ../../outputs/pubsub_publisher_sa.txt
terraform output pubsub_results_topic > ../../outputs/pubsub_results_topic.txt

# Save Pub/Sub publisher key (base64 JSON) to a file for Kubernetes secret creation
terraform output -json pubsub_publisher_service_account_key | jq -r '.' > ../../outputs/pubsub_publisher_sa_key.b64

# Display all outputs
terraform output
```

**✅ Expected Outputs:**
- Dataproc cluster name: `ride-booking-flink-cluster`
- Dataproc cluster endpoint
- Firestore database ID: `ride-booking-analytics`
- Firestore database location: `asia-south1`
- Pub/Sub topics and subscription names
- Pub/Sub publisher service account email (ride-service uses this SA key)

**⏱️ Deployment Time:** ~10-15 minutes (Dataproc cluster provisioning + Pub/Sub resources)

### 2.3 Configure kubectl for EKS

```bash
# Get EKS cluster credentials
aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1

# Verify connection
kubectl get nodes
# Should show 2-3 nodes in Ready state

# Check cluster info
kubectl cluster-info
```

**✅ Expected:** 2+ nodes in Ready state

---

## Phase 3: Build and Push Docker Images

### 3.1 Set Your Registry URL

```bash
# For AWS ECR
export REGISTRY="943812325535.dkr.ecr.ap-south-1.amazonaws.com"

# For Docker Hub (replace with your username)
export REGISTRY="<your-dockerhub-username>"
# windows $env:REGISTRY="943812325535.dkr.ecr.ap-south-1.amazonaws.com"

# Verify
echo $REGISTRY
```

### 3.2 Build and Push All Services

```bash
# Navigate to backend directory
cd ../../backend

# User Service
cd user-service
docker build -t ${REGISTRY}/user-service:latest .
#  windows -> docker build -t "$env:REGISTRY/user-service:latest" .
docker push ${REGISTRY}/user-service:latest
# docker push "$env:REGISTRY/user-service:latest"
cd ..

# Driver Service
cd driver-service
docker build -t ${REGISTRY}/driver-service:latest .
# docker build -t "$env:REGISTRY/driver-service:latest" .
docker push ${REGISTRY}/driver-service:latest
# docker push "$env:REGISTRY/driver-service:latest"
cd ..

# Ride Service
cd ride-service
docker build -t ${REGISTRY}/ride-service:latest .
# docker build -t "$env:REGISTRY/ride-service:latest" .
docker push ${REGISTRY}/ride-service:latest
# docker push "$env:REGISTRY/ride-service:latest"
cd ..

# Payment Service
cd payment-service
docker build -t ${REGISTRY}/payment-service:latest .
# docker build -t "$env:REGISTRY/payment-service:latest" .
docker push ${REGISTRY}/payment-service:latest
# docker push "$env:REGISTRY/payment-service:latest"
cd ..
```

**✅ Expected:** All images pushed successfully to registry

### 3.3 Update Kubernetes Manifests with Image References

Update the image references in all deployment files:

**Files to update:**
- `gitops/user-service-deployment.yaml`
- `gitops/driver-service-deployment.yaml`
- `gitops/ride-service-deployment.yaml`
- `gitops/payment-service-deployment.yaml`

**Change in each file:**

```yaml
# FROM:
image: user-service:latest

# TO:
image: <REGISTRY>/user-service:latest
# Example: 943812325535.dkr.ecr.ap-south-1.amazonaws.com/user-service:latest
```

**Quick sed command (Linux/Mac/Git Bash):**

```bash
cd ../gitops

# Replace with your registry URL
export REGISTRY="943812325535.dkr.ecr.ap-south-1.amazonaws.com"

sed -i "s|image: user-service:latest|image: ${REGISTRY}/user-service:latest|g" user-service-deployment.yaml
sed -i "s|image: driver-service:latest|image: ${REGISTRY}/driver-service:latest|g" driver-service-deployment.yaml
sed -i "s|image: ride-service:latest|image: ${REGISTRY}/ride-service:latest|g" ride-service-deployment.yaml
sed -i "s|image: payment-service:latest|image: ${REGISTRY}/payment-service:latest|g" payment-service-deployment.yaml
```

---

## Phase 4: Configure Kubernetes Secrets and ConfigMaps

### 4.1 Create Database Credentials Secret

```bash

aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1

# Get RDS endpoint from Terraform output (remove port number)
cd ../infra/aws
RDS_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d':' -f1)
echo "RDS Endpoint: $RDS_ENDPOINT"

# Create secret
kubectl create secret generic db-credentials \
  --from-literal=host=${RDS_ENDPOINT} \
  --from-literal=name=ridebooking \
  --from-literal=user=postgres \
  --from-literal=password=RideDB_2025!

# Verify
kubectl get secret db-credentials
```

### 4.2 Create Pub/Sub Publisher Secret

```bash
cd infra/gcp

# Pub/Sub publisher key was saved during Phase 2.2
PUBSUB_KEY_B64_FILE=../../outputs/pubsub_publisher_sa_key.b64

if [ ! -f "${PUBSUB_KEY_B64_FILE}" ]; then
  echo "Missing ${PUBSUB_KEY_B64_FILE}. Run terraform output again to capture the key."
  exit 1
fi

# Decode the base64 key into JSON (never commit this file)
base64 -d "${PUBSUB_KEY_B64_FILE}" > /tmp/pubsub-publisher.json

# Create the Kubernetes secret used by ride-service
kubectl create secret generic pubsub-credentials \
  --from-file=publisher_sa.json=/tmp/pubsub-publisher.json \
  --dry-run=client -o yaml | kubectl apply -f -

rm /tmp/pubsub-publisher.json

# Verify
kubectl get secret pubsub-credentials
```

**Important:** The base64 string from Terraform is the raw service-account key. Store it securely (password manager or secret manager) and rotate it if leaked. Never commit the decoded JSON to Git.

### 4.3 Create Application ConfigMap

```bash
# Get Lambda API Gateway URL
cd ../aws
LAMBDA_URL=$(terraform output -raw api_gateway_url)
echo "Lambda URL: $LAMBDA_URL"

# Create ConfigMap (lambda URL + Pub/Sub metadata)
PUBSUB_PROJECT_ID=$(terraform -chdir=../gcp output -raw gcp_project_id 2>/dev/null || echo "careful-cosine-478715-a0")
PUBSUB_RIDES_TOPIC=$(cat ../../outputs/pubsub_rides_topic.txt)
PUBSUB_RESULTS_TOPIC=$(cat ../../outputs/pubsub_results_topic.txt)

kubectl create configmap app-config \
  --from-literal=lambda_api_url="${LAMBDA_URL}" \
  --from-literal=pubsub_project_id="${PUBSUB_PROJECT_ID}" \
  --from-literal=pubsub_rides_topic="${PUBSUB_RIDES_TOPIC}" \
  --from-literal=pubsub_results_topic="${PUBSUB_RESULTS_TOPIC}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify
kubectl get configmap app-config
kubectl describe configmap app-config
```

**✅ Expected:** All secrets and configmaps created successfully

---

## Phase 5: Deploy ArgoCD

### 5.1 Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (takes 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Check status
kubectl get pods -n argocd
```

### 5.2 Get ArgoCD Admin Password

```bash
# For Windows PowerShell:
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

# For Linux/Mac/Git Bash:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
```

**Save this password!** You'll need it to login to ArgoCD.

### 5.3 Access ArgoCD UI

```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (from previous step)
```

**Note:** Browser may show security warning - click "Advanced" and "Proceed" (it's using self-signed certificate).

### 5.4 Configure Git Repository

You have two options:

#### Option A: Use GitHub Repository (Recommended for Production)

1. Create a new GitHub repository
2. Push your code to GitHub:

```bash
cd ../../..
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/your-username/ride-booking-platform.git
git push -u origin main
```

3. Update `gitops/argocd-apps.yaml`:

```yaml
# Change line 9 (and similar lines in all 4 applications):
repoURL: https://github.com/your-username/ride-booking-platform.git
targetRevision: main
```

4. Apply ArgoCD applications:

```bash
kubectl apply -f gitops/argocd-apps.yaml
```

#### Option B: Deploy Directly Without ArgoCD (For Testing)

If you want to test without setting up Git repository:

```bash
cd gitops

kubectl apply -f user-service-deployment.yaml
kubectl apply -f driver-service-deployment.yaml
kubectl apply -f ride-service-deployment.yaml
kubectl apply -f payment-service-deployment.yaml

# Skip to Phase 6
```

### 5.5 Verify ArgoCD Applications

```bash
# Check application status
kubectl get applications -n argocd

# Watch applications sync
kubectl get applications -n argocd -w

# Check via CLI (install ArgoCD CLI if available)
argocd app list
argocd app get user-service
```

**✅ Expected:** All 4 applications in "Synced" and "Healthy" state

---

## Phase 6: Deploy Monitoring Stack

### 6.1 Install Prometheus and Grafana

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack (includes Prometheus, Grafana, and Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --timeout 10m

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

### 6.2 Install Loki (Log Aggregation)

```bash
helm install loki grafana/loki-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

### 6.3 Access Grafana

```bash
# Get Grafana admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo ""

# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Username: admin
# Password: (from previous command)
```

### 6.4 Import Custom Dashboard

1. Login to Grafana at `http://localhost:3000`
2. Click on "Dashboards" → "Import" (+ icon on left sidebar)
3. Click "Upload JSON file"
4. Upload `monitoring/grafana/dashboards/ride-booking-dashboard.json`
5. Click "Import"

### 6.5 Add Loki as Data Source (Optional)

1. Go to Configuration → Data Sources
2. Click "Add data source"
3. Select "Loki"
4. URL: `http://loki:3100`
5. Click "Save & Test"

**✅ Expected:** Grafana accessible with dashboard showing metrics

---

## Phase 7: Deploy Flink Job on Google Dataproc

**Note:** Google Dataproc provides a managed Hadoop/Spark cluster. Flink is automatically installed via initialization script during cluster creation.

**📖 Detailed Guide:** See `infra/gcp/DEPLOYMENT_GUIDE.md` for comprehensive instructions.

### 7.1 Build Flink Job

```bash
cd analytics/flink-job

# Ensure Maven is installed
mvn --version

# Build the Flink job JAR
mvn clean package

# Verify JAR created
ls -lh target/ride-analytics-1.0.jar
```

**✅ Expected:** JAR file created at `target/ride-analytics-1.0.jar`

### 7.2 Get Dataproc Cluster Details

```bash
cd ../../infra/gcp

# Get Dataproc cluster details
CLUSTER_NAME=$(terraform output -raw dataproc_cluster_name)
REGION=$(terraform output -raw gcp_region)
ZONE=$(terraform output -raw gcp_zone)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Zone: $ZONE"
```

### 7.3 SSH to Dataproc Master Node

**SSH into Dataproc master node:**

```bash
# From your local machine
gcloud dataproc clusters ssh $CLUSTER_NAME \
  --region=$REGION \
  --zone=$ZONE
```

**✅ Expected:** Connected to Dataproc master node

### 7.4 Start Flink Cluster

**On the Dataproc master node:**

```bash
# Flink should already be installed at /opt/flink (via initialization script)
# Start Flink cluster
/opt/flink/bin/start-cluster.sh

# Verify Flink is running
/opt/flink/bin/flink list
```

**✅ Expected:** Flink cluster started successfully

### 7.5 Access Flink Web UI

**From your local machine, create SSH tunnel:**

```bash
# Get master node name
MASTER_NODE=$(gcloud dataproc clusters describe $CLUSTER_NAME \
  --region=$REGION \
  --format="value(config.masterConfig.instanceNames[0])")

# Create SSH tunnel (keep this terminal open)
gcloud compute ssh $MASTER_NODE \
  --zone=$ZONE \
  -- -L 8081:localhost:8081 -N

# Open in browser: http://localhost:8081
```

**✅ Expected:** Flink web interface showing cluster dashboard

### 7.6 Upload and Submit Flink Job

**From your local machine, upload the JAR to GCS:**

```bash
# Create a bucket for your job (if not exists)
gsutil mb -l $REGION gs://${CLUSTER_NAME}-flink-jobs || true

# Upload JAR to GCS
gsutil cp ../../analytics/flink-job/target/ride-analytics-1.0.jar \
  gs://${CLUSTER_NAME}-flink-jobs/
```

**SSH into Dataproc and submit the job:**

```bash
# SSH to master node
gcloud dataproc clusters ssh $CLUSTER_NAME --region=$REGION --zone=$ZONE

# Download JAR from GCS
gsutil cp gs://${CLUSTER_NAME}-flink-jobs/ride-analytics-1.0.jar /tmp/

# Export Pub/Sub environment variables (from Phase 2 outputs)
export PUBSUB_PROJECT_ID="careful-cosine-478715-a0"                # From terraform.tfvars
export PUBSUB_RIDES_SUBSCRIPTION="<pubsub_rides_subscription>"      # From terraform output
export PUBSUB_RESULTS_TOPIC="<pubsub_results_topic>"                # From terraform output
export FIRESTORE_COLLECTION="ride_analytics"

# Submit Flink job
/opt/flink/bin/flink run \
  -c com.ridebooking.RideAnalyticsJob \
  /tmp/ride-analytics-1.0.jar

# Verify job is running
/opt/flink/bin/flink list
```

**✅ Expected:** Job submitted successfully with JobID

### 7.7 Monitor Flink Job

**Via Flink Web UI:**
- Access: `http://localhost:8081` (via SSH tunnel from step 7.5)
- Check "Running Jobs" tab
- View job metrics, throughput, and checkpoints

**Via CLI:**

```bash
# SSH into Dataproc master
gcloud dataproc clusters ssh $CLUSTER_NAME --region=$REGION --zone=$ZONE

# List running jobs
/opt/flink/bin/flink list

# Get job details
/opt/flink/bin/flink info <job-id>

# View logs
tail -f /opt/flink/log/flink-*-jobmanager-*.log
tail -f /opt/flink/log/flink-*-taskmanager-*.log
```

**Via GCP Console:**
1. Navigate to Dataproc in GCP Console
2. Select your cluster
3. Check "Jobs" tab for running jobs
4. View logs in Cloud Logging

**✅ Expected:** Flink job running, consuming from Pub/Sub (`rides` subscription) and writing to Pub/Sub (`ride-results`) + Firestore

---

## Phase 8: Deploy Frontend

### 8.1 Install Dependencies

```bash
cd ../../frontend/nextjs-ui

# Install Node.js dependencies
npm install
```

### 8.2 Configure Environment Variables

#### Get Ride Service URL

**Option 1: Using LoadBalancer (if configured)**
```bash
kubectl get svc ride-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Option 2: Using Port-Forward (for testing)**
```bash
# In a separate terminal, keep this running:
kubectl port-forward svc/ride-service 8003:80
```

#### Create `.env.local`

```bash
# Create environment file
cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://localhost:8003
EOF
```

**For production with LoadBalancer:**
```bash
RIDE_SERVICE_URL=$(kubectl get svc ride-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://${RIDE_SERVICE_URL}
EOF
```

### 8.3 Run Frontend

#### Development Mode (Recommended for testing):

```bash
npm run dev

# Open browser: http://localhost:3000
```

#### Production Mode:

```bash
# Build for production
npm run build

# Start production server
npm start

# Open browser: http://localhost:3000
```

**✅ Expected:** Frontend accessible at http://localhost:3000

---

## Phase 9: Verify Deployment

### 9.1 Check All Kubernetes Resources

```bash
# Check all pods
kubectl get pods
# Should show 8 pods (2 replicas × 4 services)

# Check services
kubectl get svc

# Check deployments
kubectl get deployments

# Check HPAs
kubectl get hpa
# Should show ride-service-hpa and user-service-hpa

# Check secrets
kubectl get secrets

# Check configmaps
kubectl get configmaps
```

**✅ Expected Output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
user-service-xxxxx-xxxxx          1/1     Running   0          5m
user-service-xxxxx-xxxxx          1/1     Running   0          5m
driver-service-xxxxx-xxxxx        1/1     Running   0          5m
driver-service-xxxxx-xxxxx        1/1     Running   0          5m
ride-service-xxxxx-xxxxx          1/1     Running   0          5m
ride-service-xxxxx-xxxxx          1/1     Running   0          5m
payment-service-xxxxx-xxxxx       1/1     Running   0          5m
payment-service-xxxxx-xxxxx       1/1     Running   0          5m
```

### 9.2 Check Service Logs

```bash
# Check individual service logs
kubectl logs -l app=user-service --tail=50
kubectl logs -l app=driver-service --tail=50
kubectl logs -l app=ride-service --tail=50
kubectl logs -l app=payment-service --tail=50

# Follow logs in real-time
kubectl logs -l app=ride-service -f
```

### 9.3 Check AWS Lambda

```bash
aws lambda list-functions --query 'Functions[?contains(FunctionName, `notification`)]' --output table

# Test Lambda directly
aws lambda invoke \
  --function-name ride-booking-notification-lambda \
  --payload '{"body": "{\"ride_id\": 999, \"city\": \"Bangalore\"}"}' \
  response.json

cat response.json
```

### 9.4 Check Cloud Pub/Sub

```bash
cd infra/gcp
PUBSUB_PROJECT_ID=$(terraform output -raw gcp_project_id)
PUBSUB_RIDES_TOPIC=$(terraform output -raw pubsub_rides_topic)
PUBSUB_RIDES_SUBSCRIPTION=$(terraform output -raw pubsub_rides_subscription)
PUBSUB_RESULTS_TOPIC=$(terraform output -raw pubsub_results_topic)

# List topics
gcloud pubsub topics list --project $PUBSUB_PROJECT_ID

# Describe rides topic
gcloud pubsub topics describe $PUBSUB_RIDES_TOPIC --project $PUBSUB_PROJECT_ID

# Peek messages waiting for Flink (should drain quickly)
gcloud pubsub subscriptions pull $PUBSUB_RIDES_SUBSCRIPTION \
  --project $PUBSUB_PROJECT_ID \
  --auto-ack \
  --limit=5

# Create a temporary subscription to inspect aggregated results
TEMP_SUB="ride-results-debug-$RANDOM"
gcloud pubsub subscriptions create $TEMP_SUB \
  --topic=$PUBSUB_RESULTS_TOPIC \
  --project=$PUBSUB_PROJECT_ID \
  --expiration-period=86400s

gcloud pubsub subscriptions pull $TEMP_SUB \
  --project $PUBSUB_PROJECT_ID \
  --auto-ack \
  --limit=5

gcloud pubsub subscriptions delete $TEMP_SUB --project $PUBSUB_PROJECT_ID
```

### 9.5 Check Firestore (NoSQL Database)

```bash
# Get Firestore database ID
FIRESTORE_DB=$(cd infra/gcp && terraform output -raw firestore_database_id)

# Check Firestore database
gcloud firestore databases describe $FIRESTORE_DB

# List collections (via GCP Console or application code)
echo "Check Firestore at: https://console.cloud.google.com/firestore"
```

**Via GCP Console:**
1. Open https://console.cloud.google.com/firestore
2. Select your project
3. View "ride_analytics" collection
4. Check documents with aggregated data

### 9.6 Check Dataproc Flink Cluster

```bash
# Get cluster details
CLUSTER_NAME=$(cd infra/gcp && terraform output -raw dataproc_cluster_name)
REGION=$(cd infra/gcp && terraform output -raw gcp_region)
ZONE=$(cd infra/gcp && terraform output -raw gcp_zone)

# Check cluster status
gcloud dataproc clusters describe $CLUSTER_NAME \
  --region=$REGION

# List running jobs
gcloud dataproc jobs list \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --filter="status.state=RUNNING"

# Check specific job
JOB_ID="<job-id>"
gcloud dataproc jobs describe $JOB_ID --region=$REGION

# View job logs
gcloud logging read "resource.type=cloud_dataproc_cluster AND resource.labels.cluster_name=$CLUSTER_NAME" \
  --limit=50 \
  --format=json
```

**Access Flink Web UI:**
```bash
# Create SSH tunnel
MASTER_NODE=$(gcloud dataproc clusters describe $CLUSTER_NAME \
  --region=$REGION \
  --format="value(config.masterConfig.instanceNames[0])")

gcloud compute ssh $MASTER_NODE \
  --zone=$ZONE \
  -- -L 8081:localhost:8081 -N -f

# Open http://localhost:8081 in browser
```

**✅ Expected:** All components running and healthy

---

## Manual Testing Guide

### Test 1: Health Checks (Quick Verification)

```bash
# Port forward all services
kubectl port-forward svc/user-service 8001:80 &
kubectl port-forward svc/driver-service 8002:80 &
kubectl port-forward svc/ride-service 8003:80 &
kubectl port-forward svc/payment-service 8004:80 &

# Test health endpoints
curl http://localhost:8001/health  # User Service
curl http://localhost:8002/health  # Driver Service
curl http://localhost:8003/health  # Ride Service
curl http://localhost:8004/health  # Payment Service
```

**✅ Expected Response:**
```json
{"status": "healthy", "service": "user-service"}
```

### Test 2: User Registration

#### Via Frontend (Recommended):

1. Open `http://localhost:3000`
2. Navigate to `/auth`
3. Fill registration form:
   - Name: "Test User"
   - Email: "test@example.com"
   - Password: "password123"
   - User Type: "Rider"
   - City: "Bangalore"
4. Click "Register"

**✅ Expected:** Success message with user ID

#### Via API (cURL):

```bash
kubectl port-forward svc/user-service 8001:80

curl -X POST http://localhost:8001/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "password123",
    "user_type": "rider",
    "city": "Bangalore"
  }'
```

**✅ Expected Response:**
```json
{
  "id": 1,
  "name": "Test User",
  "email": "test@example.com",
  "user_type": "rider",
  "city": "Bangalore"
}
```

### Test 3: User Login

```bash
curl -X POST http://localhost:8001/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

**✅ Expected:** User object with ID

### Test 4: Create Driver Profile

```bash
kubectl port-forward svc/driver-service 8002:80

curl -X POST http://localhost:8002/driver/create \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "vehicle_number": "KA01AB1234",
    "vehicle_type": "sedan",
    "license_number": "DL123456"
  }'
```

**✅ Expected:** Driver object with ID

### Test 5: Book a Ride (Critical Integration Test)

This test validates 5 components simultaneously:
1. ✅ Ride Service (stores in RDS)
2. ✅ Payment Service (processes payment)
3. ✅ Lambda Function (sends notification)
4. ✅ Cloud Pub/Sub (`rides` topic receives event)
5. ✅ Flink Job on Dataproc (processes stream + writes results)

```bash
kubectl port-forward svc/ride-service 8003:80

curl -X POST http://localhost:8003/ride/start \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": 1,
    "driver_id": 1,
    "pickup": "Koramangala",
    "drop": "HSR Layout",
    "city": "Bangalore"
  }'
```

**✅ Expected Response:**
```json
{
  "message": "Ride started successfully",
  "ride_id": 1,
  "status": "started"
}
```

#### Verify Each Component:

**A. Check Ride Stored in Database:**
```bash
curl http://localhost:8003/ride/all
# Should return array with your ride
```

**B. Check Lambda Notification Logs:**
```bash
aws logs tail /aws/lambda/ride-booking-notification-lambda --follow --since 5m
```
**✅ Expected:** Log entry showing ride notification

**C. Check Pub/Sub Metrics:**

```bash
cd infra/gcp
PROJECT_ID=$(terraform output -raw gcp_project_id)
RIDES_TOPIC=$(terraform output -raw pubsub_rides_topic)
RIDES_SUB=$(terraform output -raw pubsub_rides_subscription)
RESULTS_TOPIC=$(terraform output -raw pubsub_results_topic)

# List topics
gcloud pubsub topics list --project $PROJECT_ID

# Pull a few ride events (should show JSON payloads)
gcloud pubsub subscriptions pull $RIDES_SUB \
  --project $PROJECT_ID \
  --limit 5 \
  --auto-ack

# Create short-lived subscription to inspect ride-results
TEMP_SUB="ride-results-debug-$RANDOM"
gcloud pubsub subscriptions create $TEMP_SUB \
  --topic $RESULTS_TOPIC \
  --project $PROJECT_ID \
  --expiration-period=3600s

gcloud pubsub subscriptions pull $TEMP_SUB \
  --project $PROJECT_ID \
  --auto-ack \
  --limit 5

gcloud pubsub subscriptions delete $TEMP_SUB --project $PROJECT_ID
```

**✅ Expected:** Messages appear in Pub/Sub `rides` topic and aggregated JSON documents appear in `ride-results`.

**D. Check Flink Job Status (Dataproc):**

```bash
# List Dataproc jobs
gcloud dataproc jobs list \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --filter="status.state=RUNNING"

# Get job details
JOB_ID="<job-id>"
gcloud dataproc jobs describe $JOB_ID --region=$REGION

# View job logs in real-time
gcloud dataproc jobs wait $JOB_ID --region=$REGION
```

**Via Flink UI:**
1. SSH tunnel to master: `gcloud compute ssh <master-node> --zone=<zone> -- -L 8081:localhost:8081 -N -f`
2. Open http://localhost:8081
3. View running jobs and metrics

**✅ Expected:** Flink job running and processing events from Pub/Sub stream

**E. Check Firestore (GCP Console):**

```bash
# Via gcloud CLI
gcloud firestore databases list

# Query documents (requires firestore emulator or application code)
# Or use GCP Console
```

**Via GCP Console:**
1. Open https://console.cloud.google.com
2. Navigate to Firestore
3. Click on "ride_analytics" collection
4. View documents with aggregated ride data

**✅ Expected:** Aggregated ride data per city stored in Firestore

### Test 6: View All Rides

```bash
curl http://localhost:8003/ride/all | jq
```

**✅ Expected:** Array of all rides

### Test 7: View Analytics

```bash
curl http://localhost:8003/analytics/latest | jq
```

**✅ Expected:** Analytics data per city

### Test 8: HPA Scaling (Load Test)

#### Step 1: Check Initial State

```bash
# Check HPA status
kubectl get hpa

# Check pod count
kubectl get pods -l app=ride-service
```

**✅ Expected:** 2 pods initially, HPA target at ~0-30% CPU

#### Step 2: Disable Notifications (Optional - for cleaner load test)

```bash
kubectl set env deployment/ride-service DISABLE_NOTIFICATIONS=true
kubectl rollout status deployment/ride-service
```

#### Step 3: Run Load Test

```bash
# Ensure ride service is accessible
export RIDE_SERVICE_URL=http://localhost:8003

# Run k6 load test
cd loadtest
k6 run ride_service_test.js
```

#### Step 4: Watch Scaling in Real-Time

**In separate terminals:**

```bash
# Terminal 1: Watch HPA
watch -n 2 kubectl get hpa

# Terminal 2: Watch pods
watch -n 2 kubectl get pods -l app=ride-service

# Terminal 3: Watch in table format
kubectl get hpa ride-service-hpa --watch
```

**✅ Expected Behavior:**
- CPU utilization increases to 70%+ within 1-2 minutes
- Pod count scales: 2 → 4 → 6 → 8 (over 2-3 minutes)
- After load test completes, CPU drops
- Pod count scales back down to 2 (after 5 minutes)

#### Step 5: Verify in Grafana

```bash
# Port forward Grafana (if not already)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open: http://localhost:3000
```

**Check Dashboard Panels:**
1. **CPU Usage - Ride Service**: Should show spike during load test
2. **HPA Pod Count**: Should show increase from 2 to 8+
3. **Request Rate**: Should show increased traffic
4. **Error Rate**: Should remain low (<10%)

### Test 9: Observability Stack

#### Prometheus

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open: http://localhost:9090
```

**Test Queries:**
```promql
# CPU usage per pod
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])

# Current replica count
kube_deployment_status_replicas{deployment="ride-service"}

# Memory usage
container_memory_usage_bytes{pod=~"ride-service.*"}

# HTTP requests (if instrumented)
rate(http_requests_total[5m])
```

#### Grafana Loki (Logs)

```bash
# Access Grafana: http://localhost:3000
```

1. Go to "Explore" (compass icon on left)
2. Select "Loki" as data source
3. Enter query: `{app="ride-service"}`
4. Click "Run query"

**✅ Expected:** Stream of logs from ride service

#### Grafana Dashboard

1. Go to "Dashboards" → "Ride Booking Platform Dashboard"
2. Verify all panels showing data:
   - CPU Usage
   - Pod Count
   - Request Rate
   - Error Rate

### Test 10: GitOps Sync (If using ArgoCD)

#### Test Auto-Sync

1. **Make a change** to `gitops/ride-service-deployment.yaml`:
   ```yaml
   # Change replicas from 2 to 3
   replicas: 3
   ```

2. **Commit and push** to Git:
   ```bash
   git add gitops/ride-service-deployment.yaml
   git commit -m "Scale ride service to 3 replicas"
   git push
   ```

3. **Watch ArgoCD sync**:
   ```bash
   # Via CLI
   argocd app get ride-service --watch
   
   # Via UI
   # Open https://localhost:8080
   # Watch application sync status
   ```

4. **Verify pods increased**:
   ```bash
   kubectl get pods -l app=ride-service
   # Should show 3 pods
   ```

**✅ Expected:** ArgoCD detects change within 3 minutes and updates deployment automatically

### Test 11: End-to-End Frontend Flow

1. **Open Frontend**: http://localhost:3000

2. **Register User** (`/auth`):
   - Fill form and register
   - ✅ Should see success message

3. **Login** (`/auth`):
   - Enter credentials and login
   - ✅ Should redirect to `/book`

4. **Book Ride** (`/book`):
   - Fill ride details
   - Click "Start Ride"
   - ✅ Should see success with ride ID

5. **View Rides** (`/rides`):
   - Navigate to rides page
   - ✅ Should see list of all rides

6. **View Analytics** (`/analytics`):
   - Navigate to analytics page
   - ✅ Should see charts with ride statistics per city

---

## Troubleshooting

### Issue: Pods Not Starting

**Symptom:** Pods stuck in `Pending`, `ImagePullBackOff`, or `CrashLoopBackOff`

**Solution:**

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common issues:
# 1. Image pull errors - verify registry and image tags
# 2. Database connection - verify secrets and RDS endpoint
# 3. Resource limits - check node capacity
```

### Issue: Database Connection Failed

**Symptom:** Services crashing with database connection errors

**Solution:**

```bash
# Verify database endpoint
kubectl get secret db-credentials -o jsonpath='{.data.host}' | base64 -d
echo ""

# Test database connectivity from pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- psql -h <RDS_ENDPOINT> -U admin -d ridebooking

# Check RDS security group allows traffic from EKS nodes
```

### Issue: HPA Not Scaling

**Symptom:** HPA shows `<unknown>` for metrics

**Solution:**

```bash
# Check if metrics server is installed
kubectl get deployment metrics-server -n kube-system

# If not installed:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics are available
kubectl top nodes
kubectl top pods
```

### Issue: Pub/Sub Connectivity Failed

**Symptom:** Ride service logs show `PermissionDenied` when publishing or Flink job can't pull messages from `rides` subscription.

**Solution:**

```bash
cd infra/gcp
PROJECT_ID=$(terraform output -raw gcp_project_id)
RIDES_TOPIC=$(terraform output -raw pubsub_rides_topic)
RIDES_SUB=$(terraform output -raw pubsub_rides_subscription)
RESULTS_TOPIC=$(terraform output -raw pubsub_results_topic)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Ensure Pub/Sub API enabled
gcloud services enable pubsub.googleapis.com --project $PROJECT_ID

# Reapply IAM bindings
gcloud pubsub subscriptions add-iam-policy-binding $RIDES_SUB \
  --project=$PROJECT_ID \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.subscriber"

gcloud pubsub topics add-iam-policy-binding $RESULTS_TOPIC \
  --project=$PROJECT_ID \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/pubsub.publisher"

# Publish a test event
gcloud pubsub topics publish $RIDES_TOPIC \
  --project=$PROJECT_ID \
  --message '{"ride_id":123,"city":"debug","timestamp":"'$(date -Iseconds)'"}'

# Pull from subscription to confirm delivery
gcloud pubsub subscriptions pull $RIDES_SUB --project=$PROJECT_ID --auto-ack --limit=5
```

### Issue: Lambda Not Triggering

**Symptom:** Notifications not appearing in CloudWatch logs

**Solution:**

```bash
# Test Lambda directly
aws lambda invoke \
  --function-name ride-booking-notification-lambda \
  --payload '{"body": "{\"ride_id\": 1, \"city\": \"Bangalore\"}"}' \
  response.json

# Check API Gateway URL
echo $LAMBDA_URL

# Verify API Gateway configured correctly
aws apigatewayv2 get-apis --query 'Items[?Name==`ride-booking-api`]'
```

### Issue: Grafana Dashboard Empty

**Symptom:** Grafana shows "No data" on panels

**Solution:**

```bash
# Verify Prometheus is scraping metrics
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
# Check all targets are "UP"

# Verify pod labels match Prometheus scrape config
kubectl get pods --show-labels
```

### Issue: ArgoCD Application OutOfSync

**Symptom:** ArgoCD shows application status as "OutOfSync"

**Solution:**

```bash
# Check application status
argocd app get <app-name>

# Sync manually
argocd app sync <app-name>

# Force sync if needed
argocd app sync <app-name> --force

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Issue: Frontend Cannot Connect to Backend

**Symptom:** Frontend shows connection errors or CORS errors

**Solution:**

```bash
# Verify ride service is accessible
kubectl port-forward svc/ride-service 8003:80

# Test from command line
curl http://localhost:8003/health

# Check NEXT_PUBLIC_API_BASE_URL in .env.local
cat frontend/nextjs-ui/.env.local

# For CORS issues, verify FastAPI CORS settings in backend services
```

### Issue: Terraform Apply Failed

**Symptom:** Terraform errors during `apply`

**Solution:**

```bash
# Check AWS/GCP credentials
aws sts get-caller-identity
gcloud auth list

# Check for resource limits or quota issues
# AWS: Check service quotas in AWS Console
# GCP: Check quota limits: gcloud compute project-info describe

# Re-run with debug logging
TF_LOG=DEBUG terraform apply

# If state is corrupted
terraform state list
terraform state rm <problematic-resource>
terraform import <resource-type> <resource-id>
```

---

## Post-Deployment Checklist

Before recording your demo video, verify:

- [ ] All Terraform infrastructure deployed successfully
- [ ] All 4 microservices running in Kubernetes (8 pods total)
- [ ] HPA configured for ride-service and user-service
- [ ] ArgoCD deployed and applications synced
- [ ] Grafana dashboard accessible and showing metrics
- [ ] Prometheus collecting metrics from all services
- [ ] Lambda function working and logging to CloudWatch
- [ ] Pub/Sub topics (`rides`, `ride-results`) created by Terraform
- [ ] Pub/Sub publisher secret (`pubsub-credentials`) created in Kubernetes
- [ ] Ride service publishing events to Pub/Sub (`rides` topic)
- [ ] Flink job running on Google Dataproc
- [ ] Flink consuming from Pub/Sub subscription and writing to `ride-results` + Firestore
- [ ] Firestore storing analytics results from Flink
- [ ] Frontend accessible and all pages working
- [ ] User registration and login working
- [ ] Ride booking end-to-end flow working
- [ ] Load test triggers HPA scaling (2→8 pods)
- [ ] All health checks passing
- [ ] Can view logs via kubectl and Grafana/Loki

---

## Quick Commands Reference

```bash
# View all resources
kubectl get all

# View pods with labels
kubectl get pods --show-labels

# View pod logs
kubectl logs -l app=<service-name> -f

# Describe resource for debugging
kubectl describe pod <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward service
kubectl port-forward svc/<service-name> <local-port>:<service-port>

# Scale deployment manually
kubectl scale deployment <deployment-name> --replicas=3

# Restart deployment
kubectl rollout restart deployment/<deployment-name>

# View HPA status
kubectl get hpa --watch

# View node resource usage
kubectl top nodes

# View pod resource usage
kubectl top pods

# Terraform common commands
cd infra/aws  # or infra/gcp
terraform plan
terraform apply
terraform destroy
terraform output
terraform state list

# ArgoCD commands
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
argocd app diff <app-name>
```

---

## Cleanup (When Done)

To avoid AWS/GCP charges:

```bash
# Delete Kubernetes resources
kubectl delete -f gitops/

# Delete monitoring stack
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
kubectl delete namespace monitoring

# Delete ArgoCD
kubectl delete namespace argocd

# Destroy GCP infrastructure
cd infra/gcp
terraform destroy
# Type 'yes' when prompted

# Destroy AWS infrastructure
cd ../aws
terraform destroy
# Type 'yes' when prompted

# Note: Firestore database deletion may take time - check GCP Console
```

---

## Additional Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Google Dataproc Documentation**: https://cloud.google.com/dataproc/docs
- **Cloud Pub/Sub Documentation**: https://cloud.google.com/pubsub/docs
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **Flink Documentation**: https://flink.apache.org/

---

## Support

If you encounter issues not covered in this guide:

1. Check pod logs: `kubectl logs <pod-name>`
2. Check events: `kubectl get events --sort-by='.lastTimestamp'`
3. Review Terraform outputs: `terraform output`
4. Check AWS CloudWatch logs for Lambda
5. Check GCP Console for Dataproc and Firestore metrics
6. Check Cloud Pub/Sub metrics in GCP Console

---

**Good luck with your deployment! 🚀**

Last Updated: November 2024

