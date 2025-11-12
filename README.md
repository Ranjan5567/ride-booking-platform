# Ride Booking Platform - BITS Cloud Computing Project

A complete multi-cloud ride booking platform demonstrating IaC, GitOps, microservices, serverless functions, stream analytics, and Kubernetes autoscaling.

## 🎯 Project Overview

This project implements a simplified ride booking platform that satisfies all requirements for the BITS Cloud Computing course (CS/SS G527). The solution is multi-cloud (AWS + Azure), infrastructure-as-code based, GitOps-managed, and fully cloud-native.

## 🏗️ Architecture

### Cloud Distribution

**AWS (Primary Cloud):**
- EKS cluster hosting 4 microservices
- RDS PostgreSQL for relational data
- Lambda function for notifications
- API Gateway for Lambda integration
- S3 for object storage
- Prometheus, Grafana, Loki for observability
- ArgoCD for GitOps

**Azure (Secondary Cloud):**
- Event Hub (Kafka-compatible) for event streaming
- HDInsight Flink for stream analytics
- Cosmos DB for NoSQL analytics storage

### Microservices

1. **User Service** (FastAPI) - User registration, login, city management
2. **Driver Service** (FastAPI) - Driver management, status updates
3. **Ride Service** (FastAPI) - Main orchestration service, triggers payment, notification, and event publishing
4. **Payment Service** (FastAPI) - Dummy payment processing (always returns SUCCESS)
5. **Notification Service** (AWS Lambda) - HTTP-triggered via API Gateway
6. **Analytics Service** (Azure Flink) - Stream processing from Event Hub to Cosmos DB

## 📁 Project Structure

```
ride-booking-platform/
├── infra/
│   ├── aws/              # Terraform AWS infrastructure
│   └── azure/            # Terraform Azure infrastructure
├── backend/
│   ├── user-service/
│   ├── driver-service/
│   ├── ride-service/
│   ├── payment-service/
│   └── notification-lambda/
├── analytics/
│   └── flink-job/        # Flink stream processing job
├── gitops/
│   └── argocd-apps.yaml  # ArgoCD application manifests
├── monitoring/
│   ├── prometheus/
│   └── grafana/
├── loadtest/
│   └── ride_service_test.js
├── frontend/
│   └── nextjs-ui/        # Next.js frontend application
└── docs/
    ├── ARCHITECTURE.md
    ├── REQUIREMENT_MAPPING.md
    └── DEMO_SCRIPT.md
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Azure CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- Docker
- Node.js 18+ (for frontend)

### 1. Deploy Infrastructure

#### AWS Infrastructure

```bash
cd infra/aws
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

#### Azure Infrastructure

```bash
cd infra/azure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### 2. Configure Kubernetes

```bash
# Get kubeconfig from Terraform output
aws eks update-kubeconfig --name ride-booking-eks --region us-east-1

# Create secrets for database and Azure credentials
kubectl create secret generic db-credentials \
  --from-literal=host=<RDS_ENDPOINT> \
  --from-literal=name=ridebooking \
  --from-literal=user=admin \
  --from-literal=password=<DB_PASSWORD>

kubectl create secret generic azure-credentials \
  --from-literal=eventhub_connection_string=<EVENTHUB_CONNECTION_STRING>

kubectl create configmap app-config \
  --from-literal=lambda_api_url=<API_GATEWAY_URL>
```

### 3. Build and Push Docker Images

```bash
# Build images for each service
cd backend/user-service
docker build -t user-service:latest .
# Tag and push to your container registry
docker tag user-service:latest <REGISTRY>/user-service:latest
docker push <REGISTRY>/user-service:latest

# Repeat for driver-service, ride-service, payment-service
```

### 4. Deploy ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 5. Configure ArgoCD Applications

Update `gitops/argocd-apps.yaml` with your Git repository URL, then apply:

```bash
kubectl apply -f gitops/argocd-apps.yaml
```

### 6. Deploy Monitoring Stack

```bash
# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Install Loki
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack -n monitoring
```

### 7. Deploy Frontend

```bash
cd frontend/nextjs-ui
npm install
npm run build
# Deploy to your hosting platform or run locally
npm start
```

### 8. Deploy Flink Job

```bash
cd analytics/flink-job
# Build the Flink job
mvn clean package

# Upload to HDInsight cluster and submit job
# Follow Azure HDInsight documentation for job submission
```

## 🧪 Load Testing

Run k6 load test to demonstrate HPA scaling:

```bash
# Set environment variable to disable notifications during load test
export DISABLE_NOTIFICATIONS=true

# Run load test
k6 run loadtest/ride_service_test.js
```

Monitor HPA scaling in Grafana dashboard.

## 📊 Observability

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Default credentials: admin/prom-operator
```

## 🔄 Flow Diagram

```
Frontend → Ride Service → RDS (Postgres)
                ↓
         Payment Service (SUCCESS)
                ↓
         Lambda (Notification)
                ↓
         Azure Event Hub
                ↓
         Flink (HDInsight)
                ↓
         Cosmos DB
                ↓
         Analytics Dashboard
```

## ✅ Requirements Mapping

| Requirement | Implementation |
|------------|----------------|
| IaC (Terraform) | ✅ Terraform modules for AWS & Azure |
| 6 Microservices | ✅ 4 EKS services + 1 Lambda + 1 Flink |
| Multi-cloud | ✅ AWS + Azure |
| Serverless | ✅ AWS Lambda |
| Stream Processing | ✅ Azure Flink (HDInsight) |
| GitOps | ✅ ArgoCD |
| HPA | ✅ Ride Service + User Service |
| Observability | ✅ Prometheus + Grafana + Loki |
| Distinct Storages | ✅ RDS (SQL), S3 (Object), Cosmos DB (NoSQL) |
| Load Testing | ✅ k6 scripts |

## 📝 Environment Variables

### Backend Services
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`
- `PAYMENT_SERVICE_URL`
- `LAMBDA_API_URL`
- `EVENTHUB_CONNECTION_STRING`
- `DISABLE_NOTIFICATIONS` (for load testing)

### Frontend
- `NEXT_PUBLIC_API_BASE_URL`

## 🐛 Troubleshooting

1. **Services not starting**: Check database connectivity and secrets
2. **HPA not scaling**: Verify metrics server is installed
3. **Event Hub connection issues**: Verify connection string format
4. **ArgoCD sync issues**: Check Git repository access and credentials

## 📚 Documentation

- [Architecture Details](docs/ARCHITECTURE.md)
- [Requirement Mapping](docs/REQUIREMENT_MAPPING.md)
- [Demo Script](docs/DEMO_SCRIPT.md)

## 🤝 Contributing

This is an academic project. For improvements, please create issues or pull requests.

## 📄 License

This project is for educational purposes as part of BITS Cloud Computing course.

## 👥 Authors

BITS Cloud Computing Project Team

---

**Note**: This is a simplified scaffold for academic demonstration. Production deployments would require additional security, monitoring, and operational considerations.

