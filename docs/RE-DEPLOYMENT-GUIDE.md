# 🚀 Complete Deployment Guide - Ride Booking Platform

**Step-by-step guide to deploy the entire multi-cloud ride booking platform from scratch.**

---

## 📋 Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [AWS Infrastructure Setup](#2-aws-infrastructure-setup)
3. [GCP Infrastructure Setup](#3-gcp-infrastructure-setup)
4. [Build and Push Docker Images](#4-build-and-push-docker-images)
5. [Configure Kubernetes](#5-configure-kubernetes)
6. [Deploy Monitoring Stack](#6-deploy-monitoring-stack)
7. [Deploy ArgoCD](#7-deploy-argocd)
8. [Deploy Application Services](#8-deploy-application-services)
9. [Deploy Analytics Pipeline](#9-deploy-analytics-pipeline)
10. [Deploy Frontend](#10-deploy-frontend)
11. [Setup Port-Forwards](#11-setup-port-forwards)
12. [Verify Deployment](#12-verify-deployment)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Prerequisites

### 1.1 Install Required Tools

Verify all tools are installed:

```bash
# Check versions
terraform --version   # >= 1.0
aws --version         # AWS CLI v2
gcloud --version      # GCP CLI
kubectl version       # Kubernetes CLI
docker --version      # Docker Desktop
helm version          # Helm v3
node --version        # Node.js 18+ (for frontend)
```

**Installation Links:**
- Terraform: https://www.terraform.io/downloads
- AWS CLI: https://aws.amazon.com/cli/
- GCP CLI: https://cloud.google.com/sdk/docs/install
- kubectl: https://kubernetes.io/docs/tasks/tools/
- Docker: https://docs.docker.com/get-docker/
- Helm: https://helm.sh/docs/intro/install/
- Node.js: https://nodejs.org/

### 1.2 Configure Cloud Credentials

#### AWS Configuration

```bash
aws configure
# Enter:
# - AWS Access Key ID: <your-access-key>
# - AWS Secret Access Key: <your-secret-key>
# - Default region name: ap-south-1
# - Default output format: json

# Verify
aws sts get-caller-identity
```

#### GCP Configuration

```bash
# Authenticate
gcloud auth login
gcloud auth application-default login

# Set your project (replace with your project ID)
gcloud config set project careful-cosine-478715-a0

# Verify
gcloud config get-value project
```

### 1.3 Enable Required GCP APIs

```bash
gcloud services enable dataproc.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable firestore.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable compute.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable pubsub.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable storage.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable storage-api.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable iam.googleapis.com --project=careful-cosine-478715-a0
gcloud services enable cloudresourcemanager.googleapis.com --project=careful-cosine-478715-a0
```

---

## 2. AWS Infrastructure Setup

### 2.1 Configure AWS Terraform Variables

```bash
cd infra/aws

# Copy example file
cp terraform.tfvars.example terraform.tfvars

```

**Example `terraform.tfvars`:**
```hcl
aws_region        = "ap-south-1"
project_name      = "ride-booking"
vpc_cidr          = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
db_name           = "ridebooking"
db_username       = "admin"
db_password       = "YourSecurePassword123!"  # CHANGE THIS!
```

### 2.2 Initialize and Apply AWS Infrastructure

```bash
cd infra/aws

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply infrastructure (takes 15-20 minutes)
terraform apply

# Type 'yes' when prompted
```

**What gets created:**
- ✅ VPC with public/private subnets
- ✅ EKS cluster with node groups
- ✅ RDS PostgreSQL database
- ✅ Lambda function (notification service)
- ✅ API Gateway
- ✅ S3 bucket
- ✅ IAM roles and policies

### 2.3 Save AWS Outputs

```bash
# Save important outputs
terraform output eks_cluster_name > ../../outputs/eks_cluster_name.txt
terraform output rds_endpoint > ../../outputs/rds_endpoint.txt
terraform output lambda_url > ../../outputs/lambda_url.txt
terraform output ecr_repository_url > ../../outputs/ecr_repository_url.txt
```

### 2.4 Configure kubectl for EKS

```bash
# Get cluster name
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name $CLUSTER_NAME

# Verify
kubectl get nodes
```

### 2.5 Install Metrics Server (Required for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
```

---

## 3. GCP Infrastructure Setup

### 3.1 Configure GCP Terraform Variables

```bash
cd infra/gcp

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
```

**Example `terraform.tfvars`:**
```hcl
gcp_project_id = "careful-cosine-478715-a0"  # Your GCP project ID
gcp_region     = "asia-south1"                # Mumbai, India
gcp_zone       = "asia-south1-b"
project_name   = "ride-booking"
dataproc_machine_type = "n1-standard-2"
dataproc_num_workers  = 2
firestore_location = "asia-south1"
```

### 3.2 Initialize and Apply GCP Infrastructure

```bash
cd infra/gcp

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply infrastructure (takes 10-15 minutes)
terraform apply

# Type 'yes' when prompted
```

**What gets created:**
- ✅ Dataproc cluster (Flink)
- ✅ Firestore database
- ✅ Pub/Sub topics and subscriptions
- ✅ Cloud NAT and networking
- ✅ IAM service accounts

### 3.3 Save GCP Outputs

```bash
# Save important outputs
terraform output dataproc_cluster_name > ../../outputs/dataproc_cluster.txt
terraform output firestore_database_id > ../../outputs/firestore_db.txt
terraform output pubsub_rides_topic > ../../outputs/pubsub_rides_topic.txt
terraform output pubsub_publisher_sa_key > ../../outputs/pubsub_publisher_sa_key.b64
```

### 3.4 Get Pub/Sub Service Account Key

```bash
# Get the service account key (base64 encoded)
terraform output -raw pubsub_publisher_sa_key > ../../outputs/pubsub_publisher_sa_key.b64

# Decode and save (for Kubernetes secret)
base64 -d ../../outputs/pubsub_publisher_sa_key.b64 > ../../outputs/publisher_sa.json
```

---

## 4. Build and Push Docker Images

### 4.1 Configure ECR Login

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get ECR repository URL
ECR_REPO=$(terraform -chdir=infra/aws output -raw ecr_repository_url | cut -d'/' -f1)

# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ECR_REPO
```

### 4.2 Build and Push All Services

```bash
# From project root
cd backend

# Build and push each service
for service in user-service driver-service ride-service payment-service; do
  echo "Building $service..."
  docker build -t $service:latest ./$service/
  docker tag $service:latest $ECR_REPO/$service:latest
  docker push $ECR_REPO/$service:latest
done
```

**Or use the provided script:**

```bash
# Windows PowerShell
.\scripts\build-and-push-all-services.ps1

# Linux/Mac
chmod +x scripts/build-and-push-all-services.sh
./scripts/build-and-push-all-services.sh
```

---

## 5. Configure Kubernetes

### 5.1 Create Database Credentials Secret

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform -chdir=infra/aws output -raw rds_endpoint)
DB_PASSWORD=$(terraform -chdir=infra/aws output -raw db_password)

# Create secret
kubectl create secret generic db-credentials \
  --from-literal=host=$RDS_ENDPOINT \
  --from-literal=name=ridebooking \
  --from-literal=user=admin \
  --from-literal=password=$DB_PASSWORD

# Verify
kubectl get secret db-credentials
```

### 5.2 Create Pub/Sub Configuration

```bash
# Get GCP project ID and Pub/Sub topic
GCP_PROJECT_ID=$(terraform -chdir=infra/gcp output -raw gcp_project_id)
PUBSUB_TOPIC=$(terraform -chdir=infra/gcp output -raw pubsub_rides_topic)
LAMBDA_URL=$(terraform -chdir=infra/aws output -raw lambda_url)

# Create ConfigMap
kubectl create configmap app-config \
  --from-literal=pubsub_project_id=$GCP_PROJECT_ID \
  --from-literal=pubsub_rides_topic=$PUBSUB_TOPIC \
  --from-literal=lambda_api_url=$LAMBDA_URL

# Create Pub/Sub credentials secret
kubectl create secret generic pubsub-credentials \
  --from-file=publisher_sa.json=outputs/publisher_sa.json

# Verify
kubectl get configmap app-config
kubectl get secret pubsub-credentials
```

---

## 6. Deploy Monitoring Stack

### 6.1 Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

### 6.2 Install Prometheus and Grafana

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --timeout 10m

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
```

### 6.3 Get Grafana Credentials

```bash
# Get admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

# Username: admin
# Password: (from above command)
```

---

## 7. Deploy ArgoCD

### 7.1 Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 7.2 Get ArgoCD Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo ""

# Username: admin
# Password: (from above command)
```

### 7.3 Deploy ArgoCD Applications (Optional)

```bash
# Deploy applications
kubectl apply -f gitops/argocd-apps.yaml
```

---

## 8. Deploy Application Services

### 8.1 Deploy All Services

```bash
# Deploy all services
kubectl apply -f gitops/user-service-deployment.yaml
kubectl apply -f gitops/driver-service-deployment.yaml
kubectl apply -f gitops/ride-service-deployment.yaml
kubectl apply -f gitops/payment-service-deployment.yaml

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/user-service
kubectl wait --for=condition=available --timeout=300s deployment/driver-service
kubectl wait --for=condition=available --timeout=300s deployment/ride-service
kubectl wait --for=condition=available --timeout=300s deployment/payment-service
```

### 8.2 Verify Services

```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPA (for ride-service)
kubectl get hpa
```

---

## 9. Deploy Analytics Pipeline

### 9.1 Upload Analytics Scripts to GCS

```bash
# Get Dataproc cluster name
CLUSTER_NAME=$(terraform -chdir=infra/gcp output -raw dataproc_cluster_name)

# Get staging bucket (from Dataproc)
STAGING_BUCKET=$(gcloud dataproc clusters describe $CLUSTER_NAME --region=asia-south1 --format="value(config.configBucket)")

# Upload initialization script
gsutil cp analytics/flink-job/python/init_install_packages.sh gs://$STAGING_BUCKET/scripts/

# Upload analytics script
gsutil cp analytics/flink-job/python/ride_analytics_standalone.py gs://$STAGING_BUCKET/scripts/
```

### 9.2 Start Analytics Job on Dataproc

```bash
# SSH into master node
gcloud compute ssh ${CLUSTER_NAME}-m --zone=asia-south1-b

# On the master node, run:
cd /tmp
gsutil cp gs://$STAGING_BUCKET/scripts/ride_analytics_standalone.py .
gsutil cp gs://$STAGING_BUCKET/scripts/init_install_packages.sh .

# Install dependencies (if not already installed)
bash init_install_packages.sh

# Start analytics script
python3 ride_analytics_standalone.py &

# Exit SSH
exit
```

### 9.3 Verify Analytics Pipeline

```bash
# Check if script is running
gcloud compute ssh ${CLUSTER_NAME}-m --zone=asia-south1-b --command="ps aux | grep ride_analytics"

# Check Firestore data (after creating some rides)
gcloud firestore databases list --project=careful-cosine-478715-a0
```

---

## 10. Deploy Frontend

### 10.1 Install Frontend Dependencies

```bash
cd frontend/nextjs-ui

# Install dependencies
npm install
```

### 10.2 Configure Environment Variables

```bash
# Create .env.local
cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://localhost:8001
NEXT_PUBLIC_RIDE_API_URL=http://localhost:8003
NEXT_PUBLIC_DRIVER_API_URL=http://localhost:8002
NEXT_PUBLIC_PAYMENT_API_URL=http://localhost:8004
EOF
```

### 10.3 Start Frontend

```bash
# Start development server
npm run dev

# Frontend will be available at: http://localhost:3000
```

---

## 11. Setup Port-Forwards

### 11.1 Start Port-Forwards for Services

```bash
# Get pod names
USER_POD=$(kubectl get pods -l app=user-service -o jsonpath='{.items[0].metadata.name}')
DRIVER_POD=$(kubectl get pods -l app=driver-service -o jsonpath='{.items[0].metadata.name}')
RIDE_POD=$(kubectl get pods -l app=ride-service -o jsonpath='{.items[0].metadata.name}')
PAYMENT_POD=$(kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

# Start port-forwards (run in separate terminals)
kubectl port-forward $USER_POD 8001:8001 &
kubectl port-forward $DRIVER_POD 8002:8002 &
kubectl port-forward $RIDE_POD 8003:8003 &
kubectl port-forward $PAYMENT_POD 8004:8004 &
```

**Or use the provided script:**

```bash
# Windows PowerShell
.\scripts\fix-all-port-forwards.ps1

# Linux/Mac
chmod +x scripts/fix-all-port-forwards.sh
./scripts/fix-all-port-forwards.sh
```

### 11.2 Start Port-Forwards for Monitoring

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80 &

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
```

---

## 12. Verify Deployment

### 12.1 Check All Services

```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPA
kubectl get hpa
```

### 12.2 Test API Endpoints

```bash
# Health checks
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health

# Test ride creation
curl -X POST http://localhost:8003/ride/start \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": 1,
    "driver_id": 1,
    "pickup": "Location A",
    "drop": "Location B",
    "city": "Mumbai"
  }'
```

### 12.3 Access Dashboards

- **Frontend:** http://localhost:3000
- **Grafana:** http://localhost:3001 (admin / password from step 6.3)
- **Prometheus:** http://localhost:9090
- **ArgoCD:** https://localhost:8080 (admin / password from step 7.2)

### 12.4 Seed Database (Optional)

```bash
# Seed with sample users and drivers
kubectl exec -it <user-service-pod> -- psql -h <rds-endpoint> -U admin -d ridebooking -f /path/to/seed-database.sql

# Or use the script
.\scripts\seed-db.ps1
```

---

## 13. Troubleshooting

### 13.1 Pods Not Starting

```bash
# Check pod logs
kubectl logs <pod-name>

# Check pod events
kubectl describe pod <pod-name>

# Common issues:
# - Missing secrets/configmaps
# - Wrong image tag
# - Database connection issues
```

### 13.2 Database Connection Issues

```bash
# Verify RDS endpoint
terraform -chdir=infra/aws output rds_endpoint

# Test connection from pod
kubectl exec -it <pod-name> -- psql -h <rds-endpoint> -U admin -d ridebooking

# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=ridebooking-sg"
```

### 13.3 Analytics Not Working

```bash
# Check Dataproc cluster
gcloud dataproc clusters list --region=asia-south1

# Check analytics script
gcloud compute ssh <cluster-name>-m --zone=asia-south1-b --command="ps aux | grep ride_analytics"

# Check Firestore
gcloud firestore databases list --project=<project-id>
```

### 13.4 Port-Forward Issues

```bash
# Kill existing port-forwards
netstat -ano | findstr ":8001 :8002 :8003 :8004"

# Restart port-forwards
.\scripts\fix-all-port-forwards.ps1
```

---

## 📝 Quick Reference

### Important Commands

```bash
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

- **Frontend:** http://localhost:3000
- **Grafana:** http://localhost:3001
- **Prometheus:** http://localhost:9090
- **ArgoCD:** https://localhost:8080

### Important Files

- **AWS Config:** `infra/aws/terraform.tfvars`
- **GCP Config:** `infra/gcp/terraform.tfvars`
- **Kubernetes Deployments:** `gitops/*.yaml`
- **Frontend Config:** `frontend/nextjs-ui/.env.local`

---

## ✅ Deployment Checklist

- [ ] Prerequisites installed
- [ ] AWS credentials configured
- [ ] GCP credentials configured
- [ ] AWS infrastructure deployed
- [ ] GCP infrastructure deployed
- [ ] Docker images built and pushed
- [ ] Kubernetes secrets created
- [ ] Kubernetes configmaps created
- [ ] Monitoring stack deployed
- [ ] ArgoCD deployed
- [ ] Application services deployed
- [ ] Analytics pipeline running
- [ ] Frontend running
- [ ] Port-forwards active
- [ ] All services verified

---

## 🎉 Deployment Complete!

Your ride booking platform is now fully deployed and ready to use!

**Next Steps:**
1. Access the frontend at http://localhost:3000
2. Create test users and drivers
3. Book rides and verify analytics
4. Monitor services in Grafana
5. Check ArgoCD for application status

**For support, refer to:**
- `DEPLOYMENT.md` - Detailed deployment guide
- `PROJECT_SUMMARY.md` - Project overview
- `MONITORING-ACCESS.md` - Monitoring access guide

---

**Last Updated:** November 2025

