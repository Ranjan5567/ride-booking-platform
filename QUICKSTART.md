# 🚀 Quick Start Guide - Ride Booking Platform

**Complete multi-cloud deployment in ~30 minutes**

---

## ⚡ Prerequisites (5 minutes)

```bash
# Verify tools installed
terraform --version  # >= 1.0
aws --version        # AWS CLI v2
gcloud version       # Google Cloud SDK
kubectl version      # Kubernetes CLI
docker --version     # Docker
helm version         # Helm v3

# Configure cloud credentials
aws configure                    # AWS
gcloud auth login                # GCP
gcloud config set project YOUR_PROJECT_ID
```

---

## 🔥 Setup Confluent Cloud Kafka (5 minutes)

1. Sign up: https://confluent.cloud/signup (Free $400 credit)
2. Create **Basic** cluster in **GCP us-central1**
3. Create topics: `rides` (3 partitions), `ride-results` (3 partitions)
4. Create API Key → Save **API Key** and **API Secret**
5. Copy **Bootstrap server** (e.g., `pkc-xxxxx.us-central1.gcp.confluent.cloud:9092`)

---

## ☁️ Deploy Infrastructure (15 minutes)

### AWS (Provider A) - 10 minutes

```bash
cd infra/aws
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
vim terraform.tfvars

terraform init
terraform apply  # Type 'yes'

# Save outputs
terraform output
```

### GCP (Provider B) - 5 minutes

```bash
cd ../gcp
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
# - gcp_project_id
# - confluent_kafka_bootstrap
# - confluent_kafka_api_key
# - confluent_kafka_api_secret

terraform init
terraform apply  # Type 'yes'

# Save outputs
terraform output
```

---

## 🐳 Build & Push Docker Images (5 minutes)

```bash
# For AWS ECR (PowerShell)
$env:REGISTRY="YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com"

(aws ecr get-login-password --region ap-south-1) | docker login --username AWS --password-stdin $env:REGISTRY

cd backend
foreach ($svc in "user-service", "driver-service", "ride-service", "payment-service") {
    cd $svc
    docker build -t "$env:REGISTRY/${svc}:latest" .
    docker push "$env:REGISTRY/${svc}:latest"
    cd ..
}
```

---

## ⚓ Configure Kubernetes (5 minutes)

```bash
# Get EKS credentials
aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1
kubectl get nodes  # Verify

# Create secrets
cd infra/aws
kubectl create secret generic db-credentials \
  --from-literal=host=$(terraform output -raw rds_endpoint | cut -d':' -f1) \
  --from-literal=name=ridebooking \
  --from-literal=user=postgres \
  --from-literal=password=RideDB_2025!

cd ../gcp
kubectl create secret generic gcp-credentials \
  --from-literal=kafka_bootstrap_servers=$(terraform output -raw kafka_bootstrap_servers) \
  --from-literal=kafka_api_key=YOUR_KEY \
  --from-literal=kafka_api_secret=YOUR_SECRET \
  --from-literal=firestore_database_id=$(terraform output -raw firestore_database_id)

# Create configmap
cd ../aws
kubectl create configmap app-config \
  --from-literal=lambda_api_url=$(terraform output -raw api_gateway_url)
```

---

## 🔄 Deploy via ArgoCD (5 minutes)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get password (PowerShell)
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

# Port forward & access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (admin / password-from-above)

# Deploy applications
kubectl apply -f gitops/argocd-apps.yaml

# Verify
kubectl get pods  # Should see 8 pods (2 per service)
```

---

## 📊 Deploy Monitoring (5 minutes)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin / password-from-above)
```

---

## 🔥 Deploy Flink Job on Dataproc (5 minutes)

```bash
# Build Flink job
cd analytics/flink-job
mvn clean package

# Get cluster info
cd ../../infra/gcp
export CLUSTER_NAME=$(terraform output -raw dataproc_cluster_name)
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"

# Upload to Cloud Storage
gsutil cp ../../analytics/flink-job/target/ride-analytics-1.0.0.jar \
  gs://${PROJECT_ID}-dataproc-staging/flink-jobs/

# Submit Flink job
gcloud dataproc jobs submit flink \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --jar=gs://${PROJECT_ID}-dataproc-staging/flink-jobs/ride-analytics-1.0.0.jar
```

---

## ✅ Verify Deployment

```bash
# Check all components
kubectl get pods                    # All pods Running
kubectl get hpa                     # HPAs active
kubectl get applications -n argocd  # ArgoCD apps Synced

# Test health
kubectl port-forward svc/ride-service 8003:80
curl http://localhost:8003/health

# Check Flink
gcloud dataproc jobs list --cluster=$CLUSTER_NAME --region=$REGION

# Check Kafka
# Login to https://confluent.cloud → Topics → rides (check messages)
```

---

## 🧪 Quick Test

```bash
# Book a ride
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

# Verify:
# 1. Check RDS: curl http://localhost:8003/ride/all
# 2. Check Kafka: Confluent Cloud UI → rides topic
# 3. Check Flink: gcloud dataproc jobs describe <job-id>
# 4. Check Firestore: GCP Console → Firestore
```

---

## 🛑 Cleanup (Save Costs!)

```bash
# Destroy infrastructure
cd infra/gcp
terraform destroy  # Type 'yes'

cd ../aws
terraform destroy  # Type 'yes'

# Delete Kafka cluster manually from https://confluent.cloud
```

---

## 💰 Cost Summary

**Total: ~$0.37/hour = $8.88/day**

- AWS: $0.17/hour (EKS + RDS + Lambda + S3)
- GCP: $0.16/hour (Dataproc + Firestore)
- Confluent: $0.04/hour (~$1/day)

**Development (60 hours):** ~$22-25 total
**Demo (10 hours):** ~$4-5 total

---

## 📚 Full Documentation

- **Detailed Guide:** See `DEPLOYMENT.md`
- **Architecture:** See `ARCHITECTURE_SUMMARY.md`
- **Troubleshooting:** See `DEPLOYMENT.md` → Troubleshooting section

---

**Need Help?** Check `DEPLOYMENT.md` for detailed step-by-step instructions!

