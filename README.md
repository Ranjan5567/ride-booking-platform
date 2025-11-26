# 🚗 Ride Booking Platform - Multi-Cloud Microservices

**A production-grade ride booking application deployed across AWS and GCP with real-time stream processing**

[![Infrastructure](https://img.shields.io/badge/IaC-Terraform-7B42BC)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/K8s-EKS-326CE5)](https://aws.amazon.com/eks/)
[![Streaming](https://img.shields.io/badge/Streaming-Apache%20Flink-E6526F)](https://flink.apache.org/)
[![Pub/Sub](https://img.shields.io/badge/Pub%2FSub-Google%20Cloud-34A853)](https://cloud.google.com/pubsub)

---

## 🎯 **Project Overview**

=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
A fully functional ride booking platform demonstrating:

- ✅ **Multi-cloud architecture** (AWS + GCP)
- ✅ **Microservices** (6 services across 2 clouds)
- ✅ **Real-time streaming** (Apache Flink on Google Dataproc)
- ✅ **GitOps deployment** (ArgoCD)
- ✅ **Auto-scaling** (HPA on EKS)
- ✅ **Observability** (Prometheus + Grafana + Loki)
- ✅ **Load testing** (k6)

**Built for:** BITS Pilani Cloud Computing Project (60 Marks)

**Provider B:** GCP (Dataproc + Firestore + Cloud Pub/Sub)

---

## 🏗️ **Architecture**

```
┌──────────────┐
│   Frontend   │ (Next.js)
└──────┬───────┘
       │
   ┌───▼──────────────────────────────────┐
   │      AWS (Provider A)                │
   │  ┌─────────────────────────────────┐│
   │  │  EKS Cluster (Kubernetes)        ││
   │  │  • User Service                  ││
   │  │  • Driver Service                ││
   │  │  • Ride Service (HPA 2-8 pods)   ││
   │  │  • Payment Service               ││
   │  └─────────────────────────────────┘│
   │  • RDS PostgreSQL                    │
   │  • AWS Lambda (Notifications)        │
   │  • S3 (Object Storage)               │
   └─────────────┬────────────────────────┘
                 │
          ┌──────▼────────┐
          │ Confluent    │
          │ Cloud Kafka  │
          │              │
          └──────┬────────┘
                 │
   ┌─────────────▼────────────────────────┐
   │      GCP (Provider B)                │
   │  ┌─────────────────────────────────┐│
   │  │ Google Dataproc (Flink)         ││
   │  │ • Real-time aggregation          ││
   │  │ • Time-windowed processing       ││
   │  └─────────────────────────────────┘│
   │  • Firestore (NoSQL Analytics)       │
   │  • Confluent Cloud (Managed Kafka)   │
   └──────────────────────────────────────┘
```

---

## 📁 **Project Structure**

```
.
├── README.md                      # This file
├── QUICKSTART.md                  # 30-minute deployment guide
├── DEPLOYMENT.md                  # Comprehensive deployment instructions
├── ARCHITECTURE_SUMMARY.md        # Architecture details & cost breakdown
├── GCP_MIGRATION_SUMMARY.md       # GCP migration notes
│
├── backend/                       # Microservices (Python FastAPI)
│   ├── user-service/              # User authentication & profiles
│   ├── driver-service/            # Driver management
│   ├── ride-service/              # Ride booking & matching
│   └── payment-service/           # Payment processing
│
├── frontend/                      # Frontend application
│   └── nextjs-ui/                 # Next.js web interface
│
├── infra/                         # Infrastructure as Code
│   ├── aws/                       # AWS Terraform (Provider A)
│   │   ├── main.tf                # EKS, RDS, Lambda, S3
│   │   └── modules/               # Modular resources
│   └── gcp/                       # GCP Terraform (Provider B)
│       ├── main.tf                # Dataproc, Firestore
│       └── modules/                # Dataproc, Firestore modules
│
├── gitops/                        # Kubernetes manifests
│   ├── user-service-deployment.yaml
│   ├── driver-service-deployment.yaml
│   ├── ride-service-deployment.yaml
│   ├── payment-service-deployment.yaml
│   └── argocd-apps.yaml           # ArgoCD application definitions
│
├── analytics/                     # Stream processing
│   └── flink-job/                 # Apache Flink job (Java)
│
├── monitoring/                    # Observability
│   └── grafana/                   # Grafana dashboards
│
└── loadtest/                      # Load testing scripts (k6)
```

---

## 🚀 **Quick Start (30 Minutes)**

### **Prerequisites**

- AWS Account + CLI configured
- GCP Account + CLI configured
- Docker, Terraform, kubectl, Helm installed

### **Deploy**

1. **Deploy Infrastructure** (10 min)

   ```bash
   # AWS
   cd infra/aws
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars
   terraform init && terraform apply

   # GCP
   cd ../gcp
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your GCP project values (Pub/Sub is auto-provisioned)
   terraform init && terraform apply
   ```

2. **Deploy Microservices** (10 min)

   ```bash
   # Build & push Docker images
   # Configure kubectl
   # Deploy via ArgoCD
   ```

3. **Deploy Flink Job** (5 min)
   ```bash
   cd analytics/flink-job
   mvn clean package
   # Upload to Flink container via REST API
   ```

**📖 See `DEPLOYMENT.md` for complete commands**

---

## 💰 **Cost Breakdown**

**Total: ~$0.27/hour = $6.48/day**

- **AWS:** $0.17/hour (EKS, RDS, Lambda, S3)
- **GCP:** $0.10/hour (Dataproc, Firestore, Pub/Sub)

**Development Cost (60 hours):** ~$18-20  
**Demo Cost (10 hours):** ~$3-4

**💡 Tip:** Destroy infrastructure when not in use!

---

## ✅ **Project Requirements Met**

| Requirement                  | Implementation                                                        | Status |
| ---------------------------- | --------------------------------------------------------------------- | ------ |
| **6 Microservices**          | user, driver, ride, payment, notification (Lambda), analytics (Flink) | ✅     |
| **Multiple Clouds**          | AWS (Provider A) + GCP (Provider B)                                   | ✅     |
| **IaC**                      | Terraform for all infrastructure                                      | ✅     |
| **Managed K8s**              | AWS EKS                                                               | ✅     |
| **HPA**                      | ride-service & user-service                                           | ✅     |
| **GitOps**                   | ArgoCD                                                                | ✅     |
| **Flink on Managed Cluster** | Google Dataproc                                                       | ✅     |
| **Managed Pub/Sub**          | Google Cloud Pub/Sub                                                  | ✅     |
| **SQL Database**             | RDS PostgreSQL                                                        | ✅     |
| **NoSQL Database**           | Firestore                                                             | ✅     |
| **Object Storage**           | S3                                                                    | ✅     |
| **Serverless**               | AWS Lambda                                                            | ✅     |
| **Observability**            | Prometheus + Grafana + Loki                                           | ✅     |
| **Load Testing**             | k6                                                                    | ✅     |

---

## 🛠️ **Technology Stack**

### **Backend**

- **Language:** Python 3.10+
- **Framework:** FastAPI
- **Database:** PostgreSQL (RDS)
- **API:** REST

### **Frontend**

- **Framework:** Next.js 14
- **Language:** TypeScript
- **Styling:** Tailwind CSS

### **Infrastructure**

- **IaC:** Terraform
- **Container Orchestration:** Kubernetes (EKS)
- **CI/CD:** GitOps with ArgoCD
- **Container Registry:** AWS ECR / Docker Hub

### **Streaming**

- **Platform:** Apache Flink 1.18
- **Cluster:** Google Dataproc
- **Message Broker:** Google Cloud Pub/Sub (rides + ride-results topics)
- **Processing:** Time-windowed aggregation

### **Monitoring**

- **Metrics:** Prometheus + Grafana
- **Logging:** Loki + Promtail
- **Alerting:** Grafana Alertmanager

---

## 📊 **Key Features**

### **1. Real-Time Stream Processing**

- Flink consumes ride events from Kafka
- Performs time-windowed aggregation (1-minute windows)
- Calculates rides per city in real-time
- Publishes results back to Kafka
- Stores aggregated data in Firestore

### **2. Auto-Scaling**

- HPA scales ride-service from 2→8 pods
- Based on CPU utilization (target: 70%)
- Tested with k6 load testing tool

### **3. Multi-Cloud Architecture**

- AWS for core application services
- GCP for analytics workload (Dataproc + Firestore)
- Confluent Cloud for managed Kafka messaging

### **4. GitOps Deployment**

- All deployments via ArgoCD
- Git as single source of truth
- Automatic sync from repository

### **5. Comprehensive Monitoring**

- Prometheus scrapes metrics from all services
- Grafana dashboards for visualization
- Loki for centralized logging

---

## 📖 **Documentation**

- **`README.md`** (this file) - Project overview
- **`DEPLOYMENT.md`** - Comprehensive step-by-step instructions

---

## 🧪 **Testing**

### **Manual Testing**

```bash
# Health check
curl http://localhost:8003/health

# Book a ride
curl -X POST http://localhost:8003/ride/start -H "Content-Type: application/json" -d '{...}'
```

### **Load Testing**

```bash
cd loadtest
k6 run ride_service_test.js
```

### **Verify HPA Scaling**

```bash
kubectl get hpa --watch
kubectl get pods -l app=ride-service --watch
```

---

## 🎓 **Learning Outcomes**

By completing this project, you will learn:

1. **Multi-Cloud Architecture** - Deploy across AWS & GCP
2. **Microservices Design** - Build & deploy distributed systems
3. **Stream Processing** - Real-time data processing with Flink
4. **Infrastructure as Code** - Terraform for cloud resources
5. **Kubernetes** - Container orchestration & auto-scaling
6. **GitOps** - Modern deployment practices with ArgoCD
7. **Observability** - Monitoring & logging best practices
8. **Load Testing** - Performance testing & validation

---

## 🏆 **Project Highlights**

- ✅ **Production-Grade:** Industry best practices
- ✅ **Cost-Optimized:** ~$20 total for development
- ✅ **Well-Documented:** Comprehensive guides
- ✅ **Fully Automated:** IaC + GitOps
- ✅ **Scalable:** HPA + Confluent Cloud Kafka + Flink
- ✅ **Observable:** Full monitoring stack

---

## 🛑 **Cleanup**

**⚠️ Important:** Destroy resources when not in use to avoid charges

```bash
# Destroy GCP
cd infra/gcp && terraform destroy

# Destroy AWS
cd infra/aws && terraform destroy

# Note: Manually delete Confluent Cloud Kafka cluster from https://confluent.cloud
```

---

## 📞 **Support**

- **Detailed Guide:** See `DEPLOYMENT.md`
- **Troubleshooting:** See `DEPLOYMENT.md` → Troubleshooting section

---

## 📝 **License**

This project is for educational purposes as part of BITS Pilani Cloud Computing coursework.

---

**Built with for Cloud Computing Project**  
**BITS Pilani | 2024**
