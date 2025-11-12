# Requirement Mapping Document

This document maps each BITS Cloud Computing course requirement to the implemented features in the Ride Booking Platform.

## Requirement 1: Infrastructure as Code (IaC) - Terraform Only

**Requirement:** All infrastructure must be provisioned using Terraform.

**Implementation:**
- ✅ **AWS Infrastructure** (`infra/aws/`)
  - VPC with public/private subnets
  - EKS cluster and node groups
  - RDS PostgreSQL instance
  - Lambda function
  - API Gateway
  - S3 bucket
  - IAM roles and policies
  
- ✅ **Azure Infrastructure** (`infra/azure/`)
  - Resource Group
  - Event Hub namespace and topic
  - HDInsight Flink cluster
  - Cosmos DB account and database
  - Storage account for HDInsight

**Files:**
- `infra/aws/main.tf`, `infra/aws/modules/*/`
- `infra/azure/main.tf`, `infra/azure/modules/*/`

**Verification:**
```bash
cd infra/aws && terraform plan
cd infra/azure && terraform plan
```

---

## Requirement 2: Six Microservices

**Requirement:** System must have 6 distinct microservices.

**Implementation:**

1. ✅ **User Service** (`backend/user-service/`)
   - FastAPI application
   - Deployed on EKS
   - Handles user registration, login, city management

2. ✅ **Driver Service** (`backend/driver-service/`)
   - FastAPI application
   - Deployed on EKS
   - Manages driver profiles and status

3. ✅ **Ride Service** (`backend/ride-service/`)
   - FastAPI application
   - Deployed on EKS
   - Main orchestration service
   - HPA scaling target

4. ✅ **Payment Service** (`backend/payment-service/`)
   - FastAPI application
   - Deployed on EKS
   - Dummy payment processing

5. ✅ **Notification Service** (`infra/aws/modules/lambda/`)
   - AWS Lambda function (Python)
   - HTTP-triggered via API Gateway
   - Serverless microservice

6. ✅ **Analytics Service** (`analytics/flink-job/`)
   - Apache Flink job (Java/Python)
   - Deployed on Azure HDInsight
   - Stream processing service

**Files:**
- `backend/*/app.py`, `backend/*/Dockerfile`
- `infra/aws/modules/lambda/function.py`
- `analytics/flink-job/src/main/java/.../RideAnalyticsJob.java`

**Verification:**
```bash
kubectl get deployments
aws lambda list-functions
```

---

## Requirement 3: Multi-Cloud Architecture

**Requirement:** System must span multiple cloud providers.

**Implementation:**
- ✅ **AWS (Primary Cloud)**
  - EKS cluster
  - RDS database
  - Lambda functions
  - API Gateway
  - S3 storage
  - Observability stack

- ✅ **Azure (Secondary Cloud)**
  - Event Hub (event streaming)
  - HDInsight Flink (stream processing)
  - Cosmos DB (analytics storage)

**Cross-Cloud Communication:**
- Ride Service (AWS) → Event Hub (Azure) via connection string
- Flink (Azure) reads from Event Hub (Azure)
- Flink (Azure) writes to Cosmos DB (Azure)
- Frontend queries analytics from Cosmos DB

**Files:**
- `infra/aws/` - AWS infrastructure
- `infra/azure/` - Azure infrastructure
- `backend/ride-service/app.py` - Event Hub publishing

**Verification:**
- Check Terraform outputs for both clouds
- Verify Event Hub connection in Ride Service logs

---

## Requirement 4: Serverless Function

**Requirement:** At least one serverless function must be implemented.

**Implementation:**
- ✅ **AWS Lambda - Notification Service**
  - Function: `notification-lambda`
  - Runtime: Python 3.11
  - Trigger: HTTP via API Gateway
  - Action: Logs ride notifications to CloudWatch
  - Can be disabled during load testing

**Files:**
- `infra/aws/modules/lambda/function.py`
- `infra/aws/modules/lambda/main.tf`
- `infra/aws/modules/api_gateway/main.tf`

**Verification:**
```bash
aws lambda invoke --function-name ride-booking-notification-lambda response.json
```

---

## Requirement 5: Stream Processing

**Requirement:** Real-time stream processing must be implemented.

**Implementation:**
- ✅ **Azure HDInsight Flink**
  - Consumes events from Event Hub
  - Aggregates rides per city per minute
  - Tumbling window: 1 minute
  - Writes results to Cosmos DB

**Processing Logic:**
1. Read ride events from Event Hub topic "rides"
2. Parse JSON and extract city
3. Group by city
4. Window by 1 minute
5. Count rides per city
6. Write to Cosmos DB collection "ride_analytics"

**Files:**
- `analytics/flink-job/src/main/java/.../RideAnalyticsJob.java`
- `analytics/flink-job/python/ride_analytics.py`
- `analytics/flink-job/pom.xml`

**Verification:**
- Submit Flink job to HDInsight cluster
- Monitor job status in Azure portal
- Check Cosmos DB for aggregated results

---

## Requirement 6: GitOps

**Requirement:** Application deployments must be managed via GitOps.

**Implementation:**
- ✅ **ArgoCD**
  - Auto-sync enabled for all applications
  - Monitors Git repository
  - Deploys Kubernetes manifests
  - Self-healing enabled

**Applications:**
- user-service
- driver-service
- ride-service
- payment-service

**Files:**
- `gitops/argocd-apps.yaml`
- `gitops/*-service-deployment.yaml`

**Verification:**
```bash
kubectl get applications -n argocd
argocd app list
```

---

## Requirement 7: Kubernetes Autoscaling (HPA)

**Requirement:** Horizontal Pod Autoscaler must be configured.

**Implementation:**
- ✅ **Ride Service HPA**
  - Min replicas: 2
  - Max replicas: 10
  - Metric: CPU utilization
  - Target: 70%
  
- ✅ **User Service HPA**
  - Min replicas: 2
  - Max replicas: 10
  - Metric: CPU utilization
  - Target: 70%

**Files:**
- `gitops/ride-service-deployment.yaml` (includes HPA)
- `gitops/user-service-deployment.yaml` (includes HPA)

**Verification:**
```bash
kubectl get hpa
# Run load test and observe scaling
k6 run loadtest/ride_service_test.js
kubectl get pods -w
```

---

## Requirement 8: Observability

**Requirement:** Comprehensive observability with metrics, logs, and dashboards.

**Implementation:**
- ✅ **Prometheus**
  - Metrics collection from all pods
  - Scrape interval: 15 seconds
  - Targets: All microservices

- ✅ **Grafana**
  - Dashboards for:
    - CPU usage per service
    - HPA pod scaling
    - Request throughput
    - Error rates

- ✅ **Loki**
  - Log aggregation from all pods
  - Queryable via Grafana

**Files:**
- `monitoring/prometheus/prometheus-config.yaml`
- `monitoring/grafana/dashboards/ride-booking-dashboard.json`

**Verification:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access Grafana at http://localhost:3000
```

---

## Requirement 9: Distinct Storage Types

**Requirement:** System must use multiple distinct storage types.

**Implementation:**
- ✅ **SQL Database (RDS PostgreSQL)**
  - Stores: users, drivers, rides, cities
  - Relational data with foreign keys
  - ACID transactions

- ✅ **NoSQL Database (Cosmos DB)**
  - Stores: aggregated analytics data
  - MongoDB API
  - Document-based storage

- ✅ **Object Storage (S3)**
  - Stores: application assets, logs
  - Versioning enabled
  - Encryption at rest

**Files:**
- `infra/aws/modules/rds/main.tf`
- `infra/azure/modules/cosmosdb/main.tf`
- `infra/aws/modules/s3/main.tf`

**Verification:**
```bash
# RDS
aws rds describe-db-instances

# Cosmos DB
az cosmosdb show --name ride-booking-cosmosdb

# S3
aws s3 ls
```

---

## Requirement 10: Load Testing

**Requirement:** Load testing must demonstrate system behavior under load.

**Implementation:**
- ✅ **k6 Load Test Script**
  - Target: Ride Service
  - Stages: Ramp up to 50 VUs, sustain, ramp down
  - Metrics: Response time, error rate
  - Triggers HPA scaling

**Files:**
- `loadtest/ride_service_test.js`

**Verification:**
```bash
# Disable notifications during load test
export DISABLE_NOTIFICATIONS=true

# Run load test
k6 run loadtest/ride_service_test.js

# Observe HPA scaling
kubectl get hpa -w
kubectl get pods -w
```

---

## Summary Table

| Requirement | Status | Implementation | Verification Method |
|------------|--------|----------------|-------------------|
| IaC (Terraform) | ✅ | AWS + Azure modules | `terraform plan` |
| 6 Microservices | ✅ | 4 EKS + 1 Lambda + 1 Flink | `kubectl get deployments` |
| Multi-cloud | ✅ | AWS + Azure | Terraform outputs |
| Serverless | ✅ | AWS Lambda | `aws lambda list-functions` |
| Stream Processing | ✅ | Azure Flink | HDInsight job status |
| GitOps | ✅ | ArgoCD | `argocd app list` |
| HPA | ✅ | Ride + User Service | `kubectl get hpa` |
| Observability | ✅ | Prometheus + Grafana + Loki | Grafana dashboards |
| Distinct Storages | ✅ | RDS + Cosmos DB + S3 | Cloud console |
| Load Testing | ✅ | k6 scripts | `k6 run` + HPA observation |

---

## Additional Features (Bonus)

- ✅ **Frontend Application** - Next.js web interface
- ✅ **API Gateway** - HTTP API for Lambda
- ✅ **Health Checks** - All services have `/health` endpoints
- ✅ **Error Handling** - Comprehensive error handling in services
- ✅ **Documentation** - Complete documentation set

---

## Compliance Checklist

- [x] All infrastructure via Terraform
- [x] 6 microservices implemented
- [x] Multi-cloud (AWS + Azure)
- [x] Serverless function (Lambda)
- [x] Stream processing (Flink)
- [x] GitOps (ArgoCD)
- [x] HPA configured
- [x] Observability stack
- [x] Multiple storage types
- [x] Load testing scripts

**All requirements satisfied! ✅**

