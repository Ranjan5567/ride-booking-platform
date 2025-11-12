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

`terraform apply` only provisions the infrastructure (VPC, EKS, RDS, Lambda, Event Hub, HDInsight, Cosmos DB, etc.). 

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
az --version         # Azure CLI
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
- Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
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
# - Default region name: us-east-1
# - Default output format: json
```

#### Azure Configuration
```bash
az login
# Follow browser login flow
# Select your subscription if you have multiple
```

### 1.3 Create Container Registry

Choose one of the following options:

#### Option A: AWS ECR (Recommended for AWS-based deployment)

```bash
# Create repositories for each service
aws ecr create-repository --repository-name user-service --region us-east-1
aws ecr create-repository --repository-name driver-service --region us-east-1
aws ecr create-repository --repository-name ride-service --region us-east-1
aws ecr create-repository --repository-name payment-service --region us-east-1

# Get ECR login command
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
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
aws_region         = "us-east-1"
project_name       = "ride-booking"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
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

### 2.2 Deploy Azure Infrastructure

```bash
cd ../azure

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars
```

**Edit `terraform.tfvars`:**

```hcl
azure_location = "eastus"
project_name   = "ride-booking"
environment    = "dev"
```

**Deploy Azure Infrastructure:**

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (this takes 20-30 minutes)
terraform apply
# Type 'yes' when prompted

# Save important outputs
terraform output eventhub_connection_string > ../../outputs/eventhub_conn.txt
terraform output cosmosdb_endpoint > ../../outputs/cosmos_endpoint.txt
terraform output hdinsight_cluster_name > ../../outputs/hdinsight_cluster.txt

# Display all outputs
terraform output
```

**✅ Expected Outputs:**
- Event Hub namespace and connection string
- Cosmos DB endpoint
- HDInsight cluster name
- Resource group name

### 2.3 Configure kubectl for EKS

```bash
# Get EKS cluster credentials
aws eks update-kubeconfig --name ride-booking-eks --region us-east-1

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
# For AWS ECR (replace <ACCOUNT_ID> with your AWS account ID)
export REGISTRY="<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com"

# For Docker Hub (replace with your username)
export REGISTRY="<your-dockerhub-username>"

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
docker push ${REGISTRY}/user-service:latest
cd ..

# Driver Service
cd driver-service
docker build -t ${REGISTRY}/driver-service:latest .
docker push ${REGISTRY}/driver-service:latest
cd ..

# Ride Service
cd ride-service
docker build -t ${REGISTRY}/ride-service:latest .
docker push ${REGISTRY}/ride-service:latest
cd ..

# Payment Service
cd payment-service
docker build -t ${REGISTRY}/payment-service:latest .
docker push ${REGISTRY}/payment-service:latest
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
# Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/user-service:latest
```

**Quick sed command (Linux/Mac/Git Bash):**

```bash
cd ../gitops

# Replace with your registry URL
export REGISTRY="123456789012.dkr.ecr.us-east-1.amazonaws.com"

sed -i "s|image: user-service:latest|image: ${REGISTRY}/user-service:latest|g" user-service-deployment.yaml
sed -i "s|image: driver-service:latest|image: ${REGISTRY}/driver-service:latest|g" driver-service-deployment.yaml
sed -i "s|image: ride-service:latest|image: ${REGISTRY}/ride-service:latest|g" ride-service-deployment.yaml
sed -i "s|image: payment-service:latest|image: ${REGISTRY}/payment-service:latest|g" payment-service-deployment.yaml
```

---

## Phase 4: Configure Kubernetes Secrets and ConfigMaps

### 4.1 Create Database Credentials Secret

```bash
# Get RDS endpoint from Terraform output (remove port number)
cd ../infra/aws
RDS_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d':' -f1)
echo "RDS Endpoint: $RDS_ENDPOINT"

# Create secret
kubectl create secret generic db-credentials \
  --from-literal=host=${RDS_ENDPOINT} \
  --from-literal=name=ridebooking \
  --from-literal=user=admin \
  --from-literal=password=YourSecurePassword123!

# Verify
kubectl get secret db-credentials
```

### 4.2 Create Azure Credentials Secret

```bash
# Get Event Hub connection string from Terraform output
cd ../azure
EVENTHUB_CONN=$(terraform output -raw eventhub_connection_string)

# Create secret
kubectl create secret generic azure-credentials \
  --from-literal=eventhub_connection_string="${EVENTHUB_CONN}"

# Verify
kubectl get secret azure-credentials
```

### 4.3 Create Application ConfigMap

```bash
# Get Lambda API Gateway URL
cd ../aws
LAMBDA_URL=$(terraform output -raw api_gateway_url)
echo "Lambda URL: $LAMBDA_URL"

# Create ConfigMap
kubectl create configmap app-config \
  --from-literal=lambda_api_url="${LAMBDA_URL}"

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

## Phase 7: Deploy Flink Job

### 7.1 Build Flink Job

```bash
cd analytics/flink-job

# Ensure Maven is installed
mvn --version

# Build the Flink job JAR
mvn clean package

# Verify JAR created
ls -lh target/ride-analytics-1.0.0.jar
```

**✅ Expected:** JAR file created at `target/ride-analytics-1.0.0.jar`

### 7.2 Get HDInsight Cluster Details

```bash
cd ../../infra/azure

# Get cluster name
CLUSTER_NAME=$(terraform output -raw hdinsight_cluster_name)
echo "HDInsight Cluster: $CLUSTER_NAME"

# Get cluster endpoint
echo "Access HDInsight at: https://${CLUSTER_NAME}.azurehdinsight.net"
```

### 7.3 Upload and Submit Flink Job

#### Via Azure Portal (Easier):

1. Open Azure Portal: https://portal.azure.com
2. Navigate to your HDInsight cluster
3. Go to "Cluster dashboards" → "Apache Ambari home"
4. Login with credentials from Terraform (default: admin/P@ssw0rd123!)
5. Go to Flink → "Submit Job"
6. Upload `target/ride-analytics-1.0.0.jar`
7. Set environment variables:
   - `EVENTHUB_NAMESPACE`: Your Event Hub namespace
   - `EVENTHUB_CONNECTION_STRING`: Your connection string
8. Submit job

#### Via Azure CLI:

```bash
# Upload JAR to cluster storage
az storage blob upload \
  --account-name <storage-account-name> \
  --container-name hdinsight \
  --name flink-jobs/ride-analytics-1.0.0.jar \
  --file ../../analytics/flink-job/target/ride-analytics-1.0.0.jar

# Submit via SSH (requires setting up SSH keys)
# See Azure HDInsight documentation for SSH setup
```

**✅ Expected:** Flink job running and consuming from Event Hub

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

### 9.4 Check Azure Event Hub

```bash
az eventhubs eventhub show \
  --resource-group ride-booking-rg \
  --namespace-name ride-booking-eh-namespace \
  --name rides \
  --output table
```

### 9.5 Check Cosmos DB

```bash
# List databases
az cosmosdb sql database list \
  --account-name ride-booking-cosmosdb \
  --resource-group ride-booking-rg

# Or check via Azure Portal
echo "Check Cosmos DB at: https://portal.azure.com"
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
4. ✅ Event Hub (receives event)
5. ✅ Flink Job (processes stream)

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

**C. Check Event Hub Metrics (Azure Portal):**
1. Open Azure Portal
2. Navigate to Event Hub namespace
3. Go to "rides" topic → Metrics
4. Check "Incoming Messages" graph

**✅ Expected:** Message count increased

**D. Check Flink Job Status (HDInsight):**
1. Access HDInsight cluster dashboard
2. Check Flink UI
3. View job metrics and processing rate

**✅ Expected:** Job processing events

**E. Check Cosmos DB (Azure Portal):**
1. Open Cosmos DB account
2. Go to Data Explorer
3. Select "analytics" database → "ride_analytics" collection
4. Query documents

**✅ Expected:** Aggregated ride data per city

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

### Issue: Event Hub Connection Failed

**Symptom:** Ride service logs show Event Hub connection errors

**Solution:**

```bash
# Verify connection string format
kubectl get secret azure-credentials -o jsonpath='{.data.eventhub_connection_string}' | base64 -d
echo ""

# Connection string should start with: Endpoint=sb://...

# Check network connectivity from EKS to Azure
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v https://<eventhub-namespace>.servicebus.windows.net
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
# Check AWS/Azure credentials
aws sts get-caller-identity
az account show

# Check for resource limits or quota issues
# AWS: Check service quotas in AWS Console
# Azure: Check subscription limits

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
- [ ] Event Hub receiving events from ride service
- [ ] Flink job running on HDInsight
- [ ] Cosmos DB storing analytics results
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
cd infra/aws  # or infra/azure
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

To avoid AWS/Azure charges:

```bash
# Delete Kubernetes resources
kubectl delete -f gitops/

# Delete monitoring stack
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
kubectl delete namespace monitoring

# Delete ArgoCD
kubectl delete namespace argocd

# Destroy Azure infrastructure
cd infra/azure
terraform destroy
# Type 'yes' when prompted

# Destroy AWS infrastructure
cd ../aws
terraform destroy
# Type 'yes' when prompted
```

---

## Additional Resources

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Azure HDInsight Documentation**: https://docs.microsoft.com/en-us/azure/hdinsight/
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
5. Check Azure Portal for Event Hub and Cosmos DB metrics

---

**Good luck with your deployment! 🚀**

Last Updated: November 2024

