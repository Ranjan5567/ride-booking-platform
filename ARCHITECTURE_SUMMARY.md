# Ride Booking Platform - Multi-Cloud Architecture Summary

## 🏗️ **Architecture Overview**

**Domain:** Ride Booking/Transportation  
**Cloud Providers:** AWS (Provider A) + GCP (Provider B) + Confluent Cloud (Kafka)  
**Deployment Model:** Multi-cloud microservices with centralized stream processing

---

## ✅ **Requirements Compliance Check**

### **a. Infrastructure as Code (IaC)** ✅
- **Tool:** Terraform 1.0+
- **AWS Infrastructure:** `infra/aws/` - VPC, EKS, RDS, Lambda, S3, API Gateway
- **GCP Infrastructure:** `infra/gcp/` - Dataproc, Firestore, VPC, Cloud Storage
- **All resources provisioned via Terraform** - No manual setup required

### **b. Microservices (6 Required)** ✅
1. **User Service** - User registration, authentication, profile management
2. **Driver Service** - Driver profiles, availability, vehicle management
3. **Ride Service** - Ride booking, matching, lifecycle management
4. **Payment Service** - Payment processing, transaction history
5. **Notification Service (Lambda)** - Async notifications via AWS Lambda
6. **Analytics Service (Flink on Dataproc)** - Real-time stream processing on GCP

**Communication:** REST APIs + Confluent Cloud Kafka for event streaming

### **c. Managed Kubernetes** ✅
- **Service:** AWS EKS (Elastic Kubernetes Service)
- **Nodes:** 2x t3.small (cost-optimized)
- **Microservices:** 4 services deployed (user, driver, ride, payment)
- **HPAs:** Configured for ride-service and user-service (CPU-based scaling)

### **d. GitOps** ✅
- **Tool:** ArgoCD
- **Repository:** GitHub (manifests in `gitops/` directory)
- **Deployments:** All K8s deployments managed via GitOps
- **Direct kubectl apply:** Forbidden for deployments

### **e. Stream Processing (Flink)** ✅
- **Cluster:** Google Dataproc (Provider B - GCP)
- **Flink Version:** 1.17.0 with native Dataproc support
- **Kafka:** Confluent Cloud (multi-cloud managed Kafka)
- **Topics:** `rides` (input), `ride-results` (output)
- **Processing:** Stateful time-windowed aggregation (rides per city per minute)

### **f. Storage Requirements** ✅
**AWS (Provider A):**
- **Object Store:** Amazon S3 (file uploads, static assets)
- **SQL Database:** Amazon RDS PostgreSQL (user accounts, ride data)

**GCP (Provider B):**
- **NoSQL Database:** Google Firestore (analytics results, session state)

**Multi-Cloud:**
- **Message Queue:** Confluent Cloud Kafka (event streaming)

### **g. Observability Stack** ✅
**Metrics:**
- **Prometheus:** Cluster and application metrics
- **Grafana:** Custom dashboard for RPS, error rate, latency, K8s health

**Logging:**
- **Loki:** Centralized log aggregation
- **Promtail:** Log collection from all microservices
- **CloudWatch:** AWS Lambda logs

### **h. Load Testing** ✅
- **Tool:** k6 (JavaScript-based load testing)
- **Target:** Ride service with HPA scaling
- **Validation:** CPU-based scaling from 2→8 pods under sustained load

---

## 🌐 **Cloud Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT / FRONTEND                             │
│                      (Next.js on localhost)                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   AWS (PROVIDER A)                                   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Amazon EKS Cluster (Kubernetes)                              │  │
│  │                                                                │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐ │  │
│  │  │User Service│  │Driver Svc  │  │Ride Service│  │Payment │ │  │
│  │  │  (2 pods)  │  │  (2 pods)  │  │  (2-8 HPA) │  │(2 pods)│ │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────┘ │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │ Monitoring: Prometheus + Grafana + Loki                   ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐│  │
│  │  │ GitOps: ArgoCD (sync from GitHub)                         ││  │
│  │  └──────────────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐   │
│  │   RDS       │    │AWS Lambda    │    │    S3 Bucket        │   │
│  │ PostgreSQL  │    │(Notification)│    │(Static Assets)      │   │
│  │(User/Rides) │    │              │    │                     │   │
│  └─────────────┘    └──────────────┘    └─────────────────────┘   │
└───────────────────────────┬───────────────────────────────────────┘
                            │
                            │ Events
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│              CONFLUENT CLOUD (KAFKA - MULTI-CLOUD)                   │
│                                                                       │
│  ┌──────────────────┐                 ┌──────────────────┐          │
│  │  Topic: rides    │────────────────▶│Topic: ride-results│         │
│  │  (3 partitions)  │                 │  (3 partitions)   │         │
│  └──────────────────┘                 └──────────────────┘          │
└───────────────────────────┬───────────────────────────────────────┘
                            │
                            │ Streaming
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     GCP (PROVIDER B)                                 │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Google Dataproc Cluster (Flink)                              │  │
│  │                                                                │  │
│  │  ┌────────────┐    ┌──────────────────────────────────────┐ │  │
│  │  │Master Node │    │ Worker Nodes (2x n1-standard-2)      │ │  │
│  │  │            │    │                                       │ │  │
│  │  │ JobManager │    │ ┌─────────────┐  ┌─────────────┐    │ │  │
│  │  │            │    │ │TaskManager 1│  │TaskManager 2│    │ │  │
│  │  │            │    │ └─────────────┘  └─────────────┘    │ │  │
│  │  └────────────┘    └──────────────────────────────────────┘ │  │
│  │                                                                │  │
│  │  Function: Time-windowed aggregation (rides per city/minute)  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Google Firestore (NoSQL)                                    │   │
│  │  Collection: ride_analytics                                  │   │
│  │  Documents: { city: string, count: number, window: timestamp}│   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Cloud Storage (GCS)                                          │   │
│  │  Bucket: Dataproc staging & Flink checkpoints                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 💰 **Cost Breakdown (Per Hour)**

### **AWS (Provider A)**
| Resource | Type | Cost/Hour |
|----------|------|-----------|
| EKS Control Plane | Managed K8s | $0.10 |
| EKS Worker Nodes | 2x t3.small | $0.04 |
| RDS PostgreSQL | db.t3.micro | $0.02 |
| Lambda | Pay-per-use | ~$0.01 |
| S3 | Storage | ~$0.001 |
| **AWS Total** | | **~$0.17/hour** |

### **GCP (Provider B)**
| Resource | Type | Cost/Hour |
|----------|------|-----------|
| Dataproc Master | 1x n1-standard-2 | $0.05 |
| Dataproc Workers | 2x n1-standard-2 | $0.10 |
| Firestore | NoSQL DB | ~$0.01 |
| Cloud Storage | GCS | ~$0.001 |
| **GCP Total** | | **~$0.16/hour** |

### **Confluent Cloud (Kafka)**
| Resource | Type | Cost/Day |
|----------|------|----------|
| Basic Cluster | Managed Kafka | ~$1.00/day |
| **Kafka Total** | | **~$0.04/hour** |

### **Grand Total: ~$0.37/hour = $8.88/day**

**For development (6 hours/day × 10 days):** ~$53-60 total project cost

---

## 🔄 **Data Flow**

1. **User Books Ride** → Ride Service (EKS)
2. **Ride Service** → Stores in RDS (AWS)
3. **Ride Service** → Publishes event to Confluent Kafka (`rides` topic)
4. **Ride Service** → Calls Lambda (notification)
5. **Flink on Dataproc** → Consumes from Kafka
6. **Flink** → Performs time-windowed aggregation (rides/city/minute)
7. **Flink** → Publishes results to Kafka (`ride-results` topic)
8. **Flink** → Stores aggregated data in Firestore (GCP)
9. **Frontend/Analytics Service** → Reads from Firestore for dashboards

---

## 🎯 **Key Features**

### **Multi-Cloud Benefits**
- ✅ **AWS**: Mature EKS, cost-effective RDS, Lambda integration
- ✅ **GCP**: Native Flink support on Dataproc, Firestore flexibility
- ✅ **Confluent Cloud**: Multi-cloud Kafka, no vendor lock-in

### **Scalability**
- HPA scales ride service 2→8 pods based on CPU
- Flink parallelism adjustable via Dataproc configuration
- Confluent Kafka auto-scales partitions

### **Reliability**
- RDS automated backups (7 days)
- Dataproc cluster auto-recovery
- Confluent Cloud 99.95% SLA

### **Observability**
- Prometheus scrapes all microservices
- Grafana visualizes metrics across clouds
- Loki aggregates logs from all sources
- CloudWatch for Lambda monitoring

---

## 📊 **Technology Stack**

**Languages:**
- Python (FastAPI) - Backend microservices
- Java (Apache Flink) - Stream processing
- JavaScript/TypeScript - Frontend (Next.js)

**Infrastructure:**
- Terraform - IaC
- Kubernetes - Container orchestration
- Docker - Containerization

**Databases:**
- PostgreSQL (RDS) - Relational data
- Firestore - NoSQL analytics

**Messaging:**
- Confluent Cloud Kafka - Event streaming

**Monitoring:**
- Prometheus + Grafana - Metrics
- Loki + Promtail - Logging

---

## 🎓 **Project Highlights**

1. ✅ **True Multi-Cloud**: AWS + GCP + Confluent (not just multi-region)
2. ✅ **Real Stream Processing**: Apache Flink with stateful operations
3. ✅ **Production-Grade**: GitOps, HPA, monitoring, load testing
4. ✅ **Cost-Optimized**: t3.small nodes, basic Kafka cluster, Firestore
5. ✅ **Industry Best Practices**: IaC, microservices, observability

---

**Last Updated:** November 2024  
**Project:** BITS Cloud Computing Assignment (60 Marks)

