# 🔄 Terraform Destroy Recovery Guide

**Complete step-by-step guide to recover and redeploy your infrastructure after accidentally running `terraform destroy`**

> ⚠️ **Important**: This guide assumes your Docker images are still available (in ECR or locally) and your Terraform configuration files are intact.

---

## 🚀 Quick Start (TL;DR)

If you're in a hurry, here's the condensed recovery process:

```powershell
# 1. Re-deploy AWS (15-20 min)
cd infra/aws
terraform init
terraform apply

# 2. Configure kubectl
$CLUSTER_NAME = terraform output -raw eks_cluster_name
aws eks update-kubeconfig --region ap-south-1 --name $CLUSTER_NAME

# 3. Re-deploy GCP (10-15 min)
cd ../gcp
terraform init
terraform apply

# 4. Configure Kubernetes secrets/configmaps (see Step 7)

# 5. Deploy monitoring, ArgoCD, and services (see Steps 8-10)

# 6. Setup port forwarding
cd ../../scripts
.\start-all-port-forwards.ps1
```

**For detailed instructions, continue reading below.**

---

## 📋 Table of Contents

1. [Pre-Recovery Checklist](#1-pre-recovery-checklist)
2. [Step 1: Verify Current State](#2-step-1-verify-current-state)
3. [Step 2: Clean Up Terraform State](#3-step-2-clean-up-terraform-state)
4. [Step 3: Re-deploy AWS Infrastructure](#4-step-3-re-deploy-aws-infrastructure)
5. [Step 4: Re-deploy GCP Infrastructure](#5-step-4-re-deploy-gcp-infrastructure)
6. [Step 5: Verify Docker Images](#6-step-5-verify-docker-images)
7. [Step 6: Rebuild/Push Docker Images (if needed)](#7-step-6-rebuildpush-docker-images-if-needed)
8. [Step 7: Configure Kubernetes](#8-step-7-configure-kubernetes)
9. [Step 8: Deploy Monitoring Stack](#9-step-8-deploy-monitoring-stack)
10. [Step 9: Deploy ArgoCD](#10-step-9-deploy-argocd)
11. [Step 10: Deploy Application Services](#11-step-10-deploy-application-services)
12. [Step 11: Deploy Analytics Pipeline](#12-step-11-deploy-analytics-pipeline)
13. [Step 12: Setup Port Forwarding](#13-step-12-setup-port-forwarding)
14. [Step 13: Verify Everything Works](#14-step-13-verify-everything-works)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Pre-Recovery Checklist

Before starting, verify you have:

- [ ] AWS CLI configured and authenticated
- [ ] GCP CLI configured and authenticated
- [ ] Terraform installed (>= 1.0)
- [ ] kubectl installed
- [ ] Docker installed and running
- [ ] Helm installed (for monitoring stack)
- [ ] Your `terraform.tfvars` files still exist
- [ ] Docker images available (in ECR or locally)

**Quick Verification:**

```powershell
# Check AWS
aws sts get-caller-identity

# Check GCP
gcloud config get-value project

# Check Terraform
terraform version

# Check kubectl
kubectl version --client

# Check Docker
docker --version
```

---

## 2. Step 1: Verify Current State

First, let's check what's actually destroyed and what still exists.

### 2.1 Check AWS Resources

```powershell
# Check if EKS cluster exists
aws eks list-clusters --region ap-south-1

# Check if RDS instances exist
aws rds describe-db-instances --region ap-south-1

# Check if ECR repositories exist
aws ecr describe-repositories --region ap-south-1

# Check if Lambda functions exist
aws lambda list-functions --region ap-south-1

# Check if S3 buckets exist
aws s3 ls
```

### 2.2 Check GCP Resources

```powershell
# Check if Dataproc clusters exist
gcloud dataproc clusters list --region=asia-south1

# Check if Firestore databases exist
gcloud firestore databases list

# Check if Pub/Sub topics exist
gcloud pubsub topics list

# Check if VPCs exist
gcloud compute networks list
```

### 2.3 Check Terraform State Files

```powershell
# Check AWS Terraform state
cd infra/aws
terraform state list

# Check GCP Terraform state
cd ../gcp
terraform state list
```

**Expected Result**: If `terraform destroy` was successful, these commands should return empty or error messages.

---

## 3. Step 2: Clean Up Terraform State

Since infrastructure was destroyed, we need to ensure Terraform state is clean for a fresh deployment.

### 3.1 Backup Existing State Files (Just in Case)

```powershell
# From project root
cd infra/aws
if (Test-Path terraform.tfstate) {
    Copy-Item terraform.tfstate terraform.tfstate.backup-$(Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item terraform.tfstate.backup terraform.tfstate.backup.old-$(Get-Date -Format "yyyyMMdd-HHmmss") -ErrorAction SilentlyContinue
}

cd ../gcp
if (Test-Path terraform.tfstate) {
    Copy-Item terraform.tfstate terraform.tfstate.backup-$(Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item terraform.tfstate.backup terraform.tfstate.backup.old-$(Get-Date -Format "yyyyMMdd-HHmmss") -ErrorAction SilentlyContinue
}
```

### 3.2 Remove Terraform State (Optional - Only if state is corrupted)

**⚠️ Only do this if Terraform state is corrupted or causing issues:**

```powershell
# AWS
cd infra/aws
Remove-Item terraform.tfstate -ErrorAction SilentlyContinue
Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue
Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue

# GCP
cd ../gcp
Remove-Item terraform.tfstate -ErrorAction SilentlyContinue
Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue
Remove-Item .terraform -Recurse -Force -ErrorAction SilentlyContinue
```

**Note**: If state files are already empty or missing, Terraform will create new ones during `terraform init`.

---

## 4. Step 3: Re-deploy AWS Infrastructure

### 4.1 Verify AWS Configuration

```powershell
cd infra/aws

# Verify terraform.tfvars exists and has correct values
Get-Content terraform.tfvars

# Expected content:
# aws_region        = "ap-south-1"
# project_name      = "ride-booking"
# vpc_cidr          = "10.0.0.0/16"
# availability_zones = ["ap-south-1a", "ap-south-1b"]
# db_name           = "ridebooking"
# db_username       = "postgres"
# db_password       = "RideDB_2025!"
```

### 4.2 Initialize Terraform

```powershell
# Initialize Terraform (downloads providers, sets up backend)
terraform init

# If you see errors about state, that's expected - we're starting fresh
```

### 4.3 Plan Infrastructure Deployment

```powershell
# Review what will be created
terraform plan

# This should show all resources being created:
# - VPC and networking
# - EKS cluster
# - RDS database
# - Lambda function
# - API Gateway
# - S3 bucket
# - ECR repositories
# - IAM roles
```

### 4.4 Apply AWS Infrastructure

```powershell
# Deploy infrastructure (takes 15-20 minutes)
terraform apply

# Type 'yes' when prompted
# ⏳ This will take 15-20 minutes - grab a coffee!
```

**What gets created:**
- ✅ VPC with public/private subnets
- ✅ EKS cluster with node groups
- ✅ RDS PostgreSQL database
- ✅ Lambda function (notification service)
- ✅ API Gateway
- ✅ S3 bucket
- ✅ ECR repositories
- ✅ IAM roles and policies

### 4.5 Save AWS Outputs

```powershell
# IMPORTANT: Make sure you're in infra/aws directory
# If not, run: cd infra/aws

# Get project root directory (two levels up from infra/aws)
$PROJECT_ROOT = (Get-Location).Path -replace '\\infra\\aws$', ''
if (-not $PROJECT_ROOT) {
    $PROJECT_ROOT = Split-Path (Split-Path (Get-Location).Path -Parent) -Parent
}

# Create outputs directory if it doesn't exist
$OUTPUTS_DIR = Join-Path $PROJECT_ROOT "outputs"
New-Item -ItemType Directory -Force -Path $OUTPUTS_DIR | Out-Null
Write-Host "Outputs directory: $OUTPUTS_DIR"

# Save important outputs
terraform output -raw eks_cluster_name | Out-File -FilePath (Join-Path $OUTPUTS_DIR "eks_cluster_name.txt") -Encoding utf8
terraform output -raw rds_endpoint | Out-File -FilePath (Join-Path $OUTPUTS_DIR "rds_endpoint.txt") -Encoding utf8
terraform output -raw lambda_url | Out-File -FilePath (Join-Path $OUTPUTS_DIR "lambda_url.txt") -Encoding utf8
terraform output -raw ecr_repository_url | Out-File -FilePath (Join-Path $OUTPUTS_DIR "ecr_repository_url.txt") -Encoding utf8

Write-Host "✅ Outputs saved to $OUTPUTS_DIR"

# Display all outputs
terraform output
```

### 4.6 Configure kubectl for EKS

```powershell
# Get cluster name
$CLUSTER_NAME = terraform output -raw eks_cluster_name

# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name $CLUSTER_NAME

# Verify connection
kubectl get nodes

# Expected: You should see 2-4 nodes (depending on your node group configuration)
```

### 4.7 Install Metrics Server (Required for HPA)

```powershell
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify installation
kubectl get deployment metrics-server -n kube-system

# Wait for it to be ready
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
```

---

## 5. Step 4: Re-deploy GCP Infrastructure

### 5.1 Verify GCP Configuration

```powershell
cd ../gcp

# Verify terraform.tfvars exists and has correct values
Get-Content terraform.tfvars

# Expected content:
# gcp_project_id = "careful-cosine-478715-a0"
# gcp_region     = "asia-south1"
# gcp_zone       = "asia-south1-b"
# project_name = "ride-booking"
# dataproc_machine_type = "n1-standard-2"
# dataproc_num_workers  = 2
# firestore_location = "asia-south1"
```

### 5.2 Verify GCP Authentication

```powershell
# Verify you're authenticated
gcloud auth list

# Verify project is set
gcloud config get-value project

# Should show: careful-cosine-478715-a0

# If not set:
gcloud config set project careful-cosine-478715-a0
```

### 5.3 Enable Required GCP APIs

```powershell
# Enable all required APIs
gcloud services enable dataproc.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable firestore.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable compute.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable pubsub.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable storage.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable storage-api.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable iam.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable cloudresourcemanager.googleapis.com --project=careful-cosine-478715-a0

# Verify APIs are enabled
gcloud services list --enabled --project=careful-cosine-478715-a0
```

### 5.4 Initialize Terraform

```powershell
# Initialize Terraform
terraform init
```

### 5.5 Plan Infrastructure Deployment

```powershell
# Review what will be created
terraform plan

# This should show:
# - Dataproc cluster
# - Firestore database
# - Pub/Sub topics and subscriptions
# - Cloud NAT and networking
# - IAM service accounts
```

### 5.6 Apply GCP Infrastructure

```powershell
# Deploy infrastructure (takes 10-15 minutes)
terraform apply

# Type 'yes' when prompted
# ⏳ This will take 10-15 minutes
```

**What gets created:**
- ✅ Dataproc cluster (Flink)
- ✅ Firestore database
- ✅ Pub/Sub topics and subscriptions
- ✅ Cloud NAT and networking
- ✅ IAM service accounts

### 5.7 Save GCP Outputs

```powershell
# IMPORTANT: Make sure you're in infra/gcp directory
# If not, run: cd infra/gcp

# Get project root directory (two levels up from infra/gcp)
$PROJECT_ROOT = (Get-Location).Path -replace '\\infra\\gcp$', ''
if (-not $PROJECT_ROOT) {
    $PROJECT_ROOT = Split-Path (Split-Path (Get-Location).Path -Parent) -Parent
}

# Create outputs directory if it doesn't exist
$OUTPUTS_DIR = Join-Path $PROJECT_ROOT "outputs"
New-Item -ItemType Directory -Force -Path $OUTPUTS_DIR | Out-Null
Write-Host "Outputs directory: $OUTPUTS_DIR"

# Save important outputs
terraform output -raw dataproc_cluster_name | Out-File -FilePath (Join-Path $OUTPUTS_DIR "dataproc_cluster.txt") -Encoding utf8
terraform output -raw firestore_database_id | Out-File -FilePath (Join-Path $OUTPUTS_DIR "firestore_db.txt") -Encoding utf8
terraform output -raw pubsub_rides_topic | Out-File -FilePath (Join-Path $OUTPUTS_DIR "pubsub_rides_topic.txt") -Encoding utf8

# Get Pub/Sub service account key (base64 encoded)
terraform output -raw pubsub_publisher_sa_key | Out-File -FilePath (Join-Path $OUTPUTS_DIR "pubsub_publisher_sa_key.b64") -Encoding utf8

# Decode and save (for Kubernetes secret)
$keyContent = terraform output -raw pubsub_publisher_sa_key
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($keyContent)) | Out-File -FilePath (Join-Path $OUTPUTS_DIR "publisher_sa.json") -Encoding utf8

Write-Host "✅ Outputs saved to $OUTPUTS_DIR"
```

---

## 6. Step 5: Verify Docker Images

### 6.1 Check ECR for Existing Images

```powershell
# Get AWS account ID
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Get ECR repository URL
$ECR_REPO = "$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"

# List repositories
aws ecr describe-repositories --region ap-south-1

# Check if images exist in repositories
$services = @("user-service", "driver-service", "ride-service", "payment-service")
foreach ($service in $services) {
    Write-Host "Checking $service..."
    aws ecr describe-images --repository-name $service --region ap-south-1 --query 'imageDetails[*].imageTags' --output table
}
```

### 6.2 Check Local Docker Images

```powershell
# List local Docker images
docker images | Select-String "user-service|driver-service|ride-service|payment-service"
```

**Decision Point:**
- ✅ **If images exist in ECR**: Skip to Step 7 (Configure Kubernetes)
- ❌ **If images don't exist**: Proceed to Step 6 (Rebuild/Push Images)

---

## 7. Step 6: Rebuild/Push Docker Images (if needed)

### 7.1 Login to ECR

```powershell
# Get AWS account ID
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Get ECR repository URL
$ECR_REPO = "$AWS_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ECR_REPO
```

### 7.2 Build and Push All Services

```powershell
# From project root
cd backend

# Build and push each service
$services = @("user-service", "driver-service", "ride-service", "payment-service")

foreach ($service in $services) {
    Write-Host "Building $service..."
    docker build -t $service`:latest .\$service\
    
    Write-Host "Tagging $service..."
    docker tag $service`:latest $ECR_REPO/$service`:latest
    
    Write-Host "Pushing $service..."
    docker push $ECR_REPO/$service`:latest
    
    Write-Host "✅ $service pushed successfully`n"
}
```

**Or use a script if available:**

```powershell
# If you have a build script
cd ../scripts
.\build-and-push-all-services.ps1
```

---

## 8. Step 7: Configure Kubernetes

### 8.1 Verify kubectl Connection

```powershell
# Make sure you're connected to the EKS cluster
kubectl cluster-info
kubectl get nodes

# Should show your EKS nodes
```

### 8.2 Create Database Credentials Secret

```powershell
# Get RDS endpoint
cd ../../infra/aws
$RDS_ENDPOINT = terraform output -raw rds_endpoint
$DB_PASSWORD = terraform output -raw db_password

# Create secret
kubectl create secret generic db-credentials `
    --from-literal=host=$RDS_ENDPOINT `
    --from-literal=name=ridebooking `
    --from-literal=user=postgres `
    --from-literal=password=$DB_PASSWORD

# Verify
kubectl get secret db-credentials
kubectl describe secret db-credentials
```

### 8.3 Create Pub/Sub Configuration

```powershell
# Get GCP project ID and Pub/Sub topic
cd ../gcp
$GCP_PROJECT_ID = terraform output -raw gcp_project_id
$PUBSUB_TOPIC = terraform output -raw pubsub_rides_topic

# Get Lambda URL
cd ../aws
$LAMBDA_URL = terraform output -raw lambda_url

# Create ConfigMap
kubectl create configmap app-config `
    --from-literal=pubsub_project_id=$GCP_PROJECT_ID `
    --from-literal=pubsub_rides_topic=$PUBSUB_TOPIC `
    --from-literal=lambda_api_url=$LAMBDA_URL

# Create Pub/Sub credentials secret
kubectl create secret generic pubsub-credentials `
    --from-file=publisher_sa.json=../../outputs/publisher_sa.json

# Verify
kubectl get configmap app-config
kubectl get secret pubsub-credentials
```

---

## 9. Step 8: Deploy Monitoring Stack

### 9.1 Create Monitoring Namespace

```powershell
kubectl create namespace monitoring
```

### 9.2 Install Prometheus and Grafana

```powershell
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana stack
helm install prometheus prometheus-community/kube-prometheus-stack `
    -n monitoring `
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
    --timeout 10m

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

### 9.3 Get Grafana Credentials

```powershell
# Get admin password
$GRAFANA_PASSWORD = kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Grafana Username: admin"
Write-Host "Grafana Password: $GRAFANA_PASSWORD"

# Save password for reference
$GRAFANA_PASSWORD | Out-File -FilePath ../../outputs/grafana_password.txt -Encoding utf8
```

---

## 10. Step 9: Deploy ArgoCD

### 10.1 Create ArgoCD Namespace

```powershell
kubectl create namespace argocd
```

### 10.2 Install ArgoCD

```powershell
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 10.3 Get ArgoCD Admin Password

```powershell
# Get initial admin password
$ARGOCD_PASSWORD = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "ArgoCD Username: admin"
Write-Host "ArgoCD Password: $ARGOCD_PASSWORD"

# Save password for reference
$ARGOCD_PASSWORD | Out-File -FilePath ../../outputs/argocd_password.txt -Encoding utf8
```

### 10.4 Deploy ArgoCD Applications (Optional)

```powershell
# Deploy applications
kubectl apply -f ../../gitops/argocd-apps.yaml
```

---

## 11. Step 10: Deploy Application Services

### 11.1 Update Deployment Files with ECR Image URLs

First, check if your deployment files need to be updated with the ECR repository URL:

```powershell
# Get ECR repository URL
cd ../../infra/aws
$ECR_REPO = terraform output -raw ecr_repository_url
$ECR_BASE = $ECR_REPO -replace '/ride-booking-.*', ''

Write-Host "ECR Base URL: $ECR_BASE"

# Check deployment files
cd ../../gitops
Get-Content user-service-deployment.yaml | Select-String "image:"
```

**If deployment files use relative image names**, you may need to update them. Check the deployment files and update image paths if needed.

### 11.2 Deploy All Services

```powershell
# Deploy all services
kubectl apply -f user-service-deployment.yaml
kubectl apply -f driver-service-deployment.yaml
kubectl apply -f ride-service-deployment.yaml
kubectl apply -f payment-service-deployment.yaml

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/user-service
kubectl wait --for=condition=available --timeout=300s deployment/driver-service
kubectl wait --for=condition=available --timeout=300s deployment/ride-service
kubectl wait --for=condition=available --timeout=300s deployment/payment-service
```

### 11.3 Verify Services

```powershell
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPA (for ride-service)
kubectl get hpa

# Check pod logs if any are not running
kubectl logs -l app=user-service --tail=50
kubectl logs -l app=driver-service --tail=50
kubectl logs -l app=ride-service --tail=50
kubectl logs -l app=payment-service --tail=50
```

---

## 12. Step 11: Deploy Analytics Pipeline

### 12.1 Upload Analytics Scripts to GCS

```powershell
# Get Dataproc cluster name
cd ../../infra/gcp
$CLUSTER_NAME = terraform output -raw dataproc_cluster_name

# Get staging bucket (from Dataproc)
$STAGING_BUCKET = (gcloud dataproc clusters describe $CLUSTER_NAME --region=asia-south1 --format="value(config.configBucket)")

Write-Host "Staging Bucket: $STAGING_BUCKET"

# Upload initialization script
gsutil cp ../../analytics/flink-job/python/init_install_packages.sh gs://$STAGING_BUCKET/scripts/

# Upload analytics script
gsutil cp ../../analytics/flink-job/python/ride_analytics_standalone.py gs://$STAGING_BUCKET/scripts/
```

### 12.2 Start Analytics Job on Dataproc

```powershell
# SSH into master node
gcloud compute ssh "${CLUSTER_NAME}-m" --zone=asia-south1-b

# On the master node, run:
# cd /tmp
# gsutil cp gs://$STAGING_BUCKET/scripts/ride_analytics_standalone.py .
# gsutil cp gs://$STAGING_BUCKET/scripts/init_install_packages.sh .
# bash init_install_packages.sh
# python3 ride_analytics_standalone.py &

# Exit SSH
# exit
```

**Or run commands remotely:**

```powershell
# Copy files to master node
gcloud compute scp ../../analytics/flink-job/python/ride_analytics_standalone.py "${CLUSTER_NAME}-m":/tmp/ --zone=asia-south1-b
gcloud compute scp ../../analytics/flink-job/python/init_install_packages.sh "${CLUSTER_NAME}-m":/tmp/ --zone=asia-south1-b

# Run initialization and start analytics
gcloud compute ssh "${CLUSTER_NAME}-m" --zone=asia-south1-b --command="cd /tmp && bash init_install_packages.sh && nohup python3 ride_analytics_standalone.py > /tmp/analytics.log 2>&1 &"
```

### 12.3 Verify Analytics Pipeline

```powershell
# Check if script is running
gcloud compute ssh "${CLUSTER_NAME}-m" --zone=asia-south1-b --command="ps aux | grep ride_analytics"

# Check Firestore data (after creating some rides)
gcloud firestore databases list --project=careful-cosine-478715-a0
```

---

## 13. Step 12: Setup Port Forwarding

### 13.1 Kill Existing Port-Forwards

```powershell
# Kill any existing kubectl port-forward processes
Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Stop-Process -Force -ErrorAction SilentlyContinue

# Check if ports are in use
netstat -ano | findstr ":8001 :8002 :8003 :8004 :3001 :9090 :8080"
```

### 13.2 Start All Port-Forwards

**Option 1: Use the provided script (Recommended)**

```powershell
# From project root
cd scripts
.\start-all-port-forwards.ps1
```

**Option 2: Manual port-forwarding**

```powershell
# Get pod names
$USER_POD = kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}'
$DRIVER_POD = kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}'
$RIDE_POD = kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}'
$PAYMENT_POD = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

# Start port-forwards in separate PowerShell windows
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$USER_POD 8001:8001"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$DRIVER_POD 8002:8002"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$RIDE_POD 8003:8001"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward pod/$PAYMENT_POD 8004:8004"

# Monitoring dashboards
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n argocd svc/argocd-server 8080:443"
```

### 13.3 Verify Port-Forwards

```powershell
# Test each service
$services = @{
    8001 = "User Service"
    8002 = "Driver Service"
    8003 = "Ride Service"
    8004 = "Payment Service"
}

foreach ($port in $services.Keys) {
    $name = $services[$port]
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "✅ Port $port ($name): WORKING" -ForegroundColor Green
    } catch {
        Write-Host "❌ Port $port ($name): NOT WORKING" -ForegroundColor Red
    }
}
```

---

## 14. Step 13: Verify Everything Works

### 14.1 Check All Services

```powershell
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPA
kubectl get hpa

# Check all resources
kubectl get all
```

### 14.2 Test API Endpoints

```powershell
# Health checks
Invoke-WebRequest -Uri "http://localhost:8001/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8002/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8003/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://localhost:8004/health" -UseBasicParsing

# Test ride creation
$body = @{
    rider_id = 1
    driver_id = 1
    pickup = "Location A"
    drop = "Location B"
    city = "Mumbai"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8003/ride/start" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -UseBasicParsing
```

### 14.3 Access Dashboards

- **Frontend:** http://localhost:3000 (if running locally)
- **Grafana:** http://localhost:3001 (admin / password from Step 9.3)
- **Prometheus:** http://localhost:9090
- **ArgoCD:** https://localhost:8080 (admin / password from Step 10.3)

### 14.4 Seed Database (Optional)

```powershell
# If you have a seed script
cd scripts
.\seed-db.ps1
```

---

## 15. Troubleshooting

### 15.1 Terraform State Issues

**Problem**: Terraform shows resources that don't exist

```powershell
# Remove state for specific resource
terraform state rm <resource_address>

# Or refresh state
terraform refresh
```

### 15.2 Pods Not Starting

```powershell
# Check pod logs
kubectl logs <pod-name>

# Check pod events
kubectl describe pod <pod-name>

# Common issues:
# - Missing secrets/configmaps
# - Wrong image tag
# - Database connection issues
# - Resource limits
```

### 15.3 Database Connection Issues

```powershell
# Verify RDS endpoint
cd infra/aws
terraform output rds_endpoint

# Test connection from pod
kubectl exec -it <pod-name> -- psql -h <rds-endpoint> -U postgres -d ridebooking

# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=ridebooking-sg" --region ap-south-1
```

### 15.4 ECR Image Pull Issues

```powershell
# Verify ECR login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# Check if images exist
aws ecr describe-images --repository-name user-service --region ap-south-1

# Check EKS node IAM role has ECR permissions
```

### 15.5 Analytics Not Working

```powershell
# Check Dataproc cluster
gcloud dataproc clusters list --region=asia-south1

# Check analytics script
gcloud compute ssh <cluster-name>-m --zone=asia-south1-b --command="ps aux | grep ride_analytics"

# Check Firestore
gcloud firestore databases list --project=careful-cosine-478715-a0

# Check Pub/Sub
gcloud pubsub topics list
gcloud pubsub subscriptions list
```

### 15.6 Port-Forward Issues

```powershell
# Kill existing port-forwards
Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Stop-Process -Force

# Check if ports are in use
netstat -ano | findstr ":8001 :8002 :8003 :8004"

# Restart port-forwards
.\scripts\start-all-port-forwards.ps1
```

### 15.7 Missing Secrets or ConfigMaps

```powershell
# Recreate secrets
kubectl delete secret db-credentials
kubectl delete secret pubsub-credentials
kubectl delete configmap app-config

# Then re-run Step 7 (Configure Kubernetes)
```

---

## ✅ Recovery Checklist

Use this checklist to track your progress:

- [ ] Step 1: Verified current state
- [ ] Step 2: Cleaned up Terraform state
- [ ] Step 3: Re-deployed AWS infrastructure
- [ ] Step 4: Re-deployed GCP infrastructure
- [ ] Step 5: Verified Docker images
- [ ] Step 6: Rebuilt/pushed Docker images (if needed)
- [ ] Step 7: Configured Kubernetes (secrets, configmaps)
- [ ] Step 8: Deployed monitoring stack
- [ ] Step 9: Deployed ArgoCD
- [ ] Step 10: Deployed application services
- [ ] Step 11: Deployed analytics pipeline
- [ ] Step 12: Setup port forwarding
- [ ] Step 13: Verified everything works

---

## 📝 Quick Reference

### Important Commands

```powershell
# Get cluster info
kubectl cluster-info

# Get all resources
kubectl get all

# View logs
kubectl logs -f <pod-name>

# Restart deployment
kubectl rollout restart deployment/<service-name>

# Scale deployment
kubectl scale deployment/<service-name> --replicas=3
```

### Important URLs

- **User Service:** http://localhost:8001
- **Driver Service:** http://localhost:8002
- **Ride Service:** http://localhost:8003
- **Payment Service:** http://localhost:8004
- **Grafana:** http://localhost:3001
- **Prometheus:** http://localhost:9090
- **ArgoCD:** https://localhost:8080
- **Frontend:** http://localhost:3000

### Important Files

- **AWS Config:** `infra/aws/terraform.tfvars`
- **GCP Config:** `infra/gcp/terraform.tfvars`
- **Kubernetes Deployments:** `gitops/*.yaml`
- **Port Forward Script:** `scripts/start-all-port-forwards.ps1`

---

## 🎉 Recovery Complete!

Your infrastructure has been successfully recovered and redeployed!

**Next Steps:**
1. ✅ Verify all services are running
2. ✅ Test the frontend at http://localhost:3000
3. ✅ Create test users and drivers
4. ✅ Book rides and verify analytics
5. ✅ Monitor services in Grafana
6. ✅ Check ArgoCD for application status

**For future reference:**
- Always backup Terraform state before running `terraform destroy`
- Consider using remote state (S3 backend) for better state management
- Use `terraform plan` before `terraform apply` to review changes

---

**Last Updated:** December 2024

