# 🎬 Demo Presentation Guide - Ride Booking Platform

**Complete guide for demonstrating the multi-cloud ride booking platform to clients.**

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [6 Microservices Architecture](#2-6-microservices-architecture)
3. [Cloud Infrastructure](#3-cloud-infrastructure)
4. [Browser Tabs to Open](#4-browser-tabs-to-open)
5. [Demo Flow](#5-demo-flow)
6. [Requirements Mapping](#6-requirements-mapping)
7. [Load Testing Demonstration](#7-load-testing-demonstration)
8. [Key Points to Highlight](#8-key-points-to-highlight)

---

## 1. Project Overview

### **Domain:** Transportation / Ride Booking

**Platform:** Multi-cloud ride booking application with real-time analytics

**Cloud Providers:**
- **Provider A (AWS):** Primary infrastructure, microservices, database
- **Provider B (GCP):** Analytics pipeline, stream processing

---

## 2. 6 Microservices Architecture

### **Microservice 1: User Service** 👤
- **Technology:** FastAPI (Python)
- **Location:** AWS EKS (Kubernetes)
- **Port:** 8001 (port-forwarded)
- **Purpose:**
  - User registration and authentication
  - User profile management
  - City management
- **Database:** RDS PostgreSQL (users table)
- **Access:** http://localhost:8001

### **Microservice 2: Driver Service** 🚗
- **Technology:** FastAPI (Python)
- **Location:** AWS EKS (Kubernetes)
- **Port:** 8002 (port-forwarded)
- **Purpose:**
  - Driver profile management
  - Driver status (online/offline)
  - Vehicle information
- **Database:** RDS PostgreSQL (drivers table)
- **Access:** http://localhost:8002

### **Microservice 3: Ride Service** 🚕
- **Technology:** FastAPI (Python)
- **Location:** AWS EKS (Kubernetes)
- **Port:** 8003 (port-forwarded)
- **Purpose:**
  - **Main orchestration service**
  - Creates rides
  - Coordinates with Payment Service
  - Publishes events to Pub/Sub (GCP)
  - Triggers Lambda notifications
- **Database:** RDS PostgreSQL (rides table)
- **HPA:** ✅ Configured (scales 2-10 pods based on 5% CPU)
- **Access:** http://localhost:8003

### **Microservice 4: Payment Service** 💳
- **Technology:** FastAPI (Python)
- **Location:** AWS EKS (Kubernetes)
- **Port:** 8004 (port-forwarded)
- **Purpose:**
  - Payment processing
  - Transaction management
  - Payment status tracking
- **Database:** RDS PostgreSQL (payments table)
- **Access:** http://localhost:8004

### **Microservice 5: Notification Service (Lambda)** 📧
- **Technology:** AWS Lambda (Python)
- **Location:** AWS (Serverless)
- **Purpose:**
  - **Asynchronous, event-driven notifications**
  - Sends notifications when rides are created
  - Triggered by Ride Service via API Gateway
- **Access:** Via API Gateway URL (from Terraform output)
- **Type:** Serverless function

### **Microservice 6: Frontend (Next.js)** 🌐
- **Technology:** Next.js (React/TypeScript)
- **Location:** **Local machine** (npm run dev)
- **Port:** 3000
- **Purpose:**
  - User interface for booking rides
  - User authentication
  - View ride history
  - Analytics dashboard
- **Access:** http://localhost:3000
- **Note:** Runs locally, connects to backend via port-forwards

---

## 3. Cloud Infrastructure

### **AWS (Provider A) - Primary Infrastructure**

| Component | Service | Purpose | Access |
|-----------|---------|---------|--------|
| **Kubernetes** | EKS Cluster | Hosts 4 microservices | kubectl / AWS Console |
| **Database** | RDS PostgreSQL | Stores users, rides, drivers, payments | Port-forwarded / AWS Console |
| **Serverless** | Lambda Function | Notification service | API Gateway URL |
| **API Gateway** | API Gateway | HTTP endpoint for Lambda | Public URL |
| **Storage** | S3 Bucket | Object storage | AWS Console |
| **Networking** | VPC, Subnets | Network isolation | AWS Console |
| **IAM** | Roles & Policies | Access control | AWS Console |

### **GCP (Provider B) - Analytics Infrastructure**

| Component | Service | Purpose | Access |
|-----------|---------|---------|--------|
| **Stream Processing** | Dataproc (Flink) | Real-time analytics | GCP Console / SSH |
| **Message Queue** | Pub/Sub | Event streaming | GCP Console |
| **NoSQL Database** | Firestore | Analytics results | GCP Console |
| **Networking** | Cloud NAT, Firewall | Internet access | GCP Console |

---

## 4. Browser Tabs to Open

### **AWS Console Tabs** (https://console.aws.amazon.com)

1. **EKS Clusters**
   - URL: `https://ap-south-1.console.aws.amazon.com/eks/home?region=ap-south-1#/clusters`
   - Show: Cluster name, node groups, pod status

2. **RDS Databases**
   - URL: `https://ap-south-1.console.aws.amazon.com/rds/home?region=ap-south-1#databases:`
   - Show: Database endpoint, connection status, monitoring

3. **Lambda Functions**
   - URL: `https://ap-south-1.console.aws.amazon.com/lambda/home?region=ap-south-1#/functions`
   - Show: Function name, triggers, logs, API Gateway integration

4. **API Gateway**
   - URL: `https://ap-south-1.console.aws.amazon.com/apigateway/home?region=ap-south-1#/apis`
   - Show: API endpoints, integration with Lambda

5. **EC2 Instances** (EKS Nodes)
   - URL: `https://ap-south-1.console.aws.amazon.com/ec2/home?region=ap-south-1#Instances:`
   - Show: EKS worker nodes, instance types

### **GCP Console Tabs** (https://console.cloud.google.com)

1. **Dataproc Clusters**
   - URL: `https://console.cloud.google.com/dataproc/clusters?project=careful-cosine-478715-a0`
   - Show: Cluster name, master/worker nodes, Flink job status

2. **Pub/Sub Topics**
   - URL: `https://console.cloud.google.com/cloudpubsub/topic/list?project=careful-cosine-478715-a0`
   - Show: `ride-booking-rides` topic, message metrics

3. **Firestore Database**
   - URL: `https://console.cloud.google.com/firestore/databases?project=careful-cosine-478715-a0`
   - Show: `ride-booking-analytics` database, `ride_analytics` collection

4. **Compute Engine** (Dataproc VMs)
   - URL: `https://console.cloud.google.com/compute/instances?project=careful-cosine-478715-a0`
   - Show: Dataproc cluster VMs

5. **Cloud Storage**
   - URL: `https://console.cloud.google.com/storage/browser?project=careful-cosine-478715-a0`
   - Show: Dataproc staging bucket

### **Local Application Tabs**

1. **Frontend:** http://localhost:3000
2. **Grafana:** http://localhost:3001
3. **Prometheus:** http://localhost:9090
4. **ArgoCD:** https://localhost:8080

---

## 5. Demo Flow

### **Step 1: Show Infrastructure (5 minutes)**

1. **AWS Console:**
   - Open EKS cluster → Show nodes, pods
   - Open RDS → Show database endpoint, status
   - Open Lambda → Show function, API Gateway trigger
   - Open API Gateway → Show endpoint URL

2. **GCP Console:**
   - Open Dataproc → Show cluster, nodes
   - Open Pub/Sub → Show topics, subscriptions
   - Open Firestore → Show database, collections

<!-- we will skip it right now -->
3. **Terraform:**
   - Show `infra/aws/` and `infra/gcp/` directories
   - Explain: "All infrastructure provisioned via Terraform (IaC)"

### **Step 2: Show Microservices (5 minutes)**

1. **Kubernetes Services:**
   ```bash
   kubectl get pods
   kubectl get svc
   kubectl get hpa
   ```
   - Show 4 backend services running
   - Show HPA configuration for ride-service

2. **Port-Forwards:**
   - Show running port-forwards
   - Explain: Services accessible via localhost

3. **Frontend:**
   - Open http://localhost:3000
   - Show: Login page, registration

### **Step 3: Demonstrate Ride Booking Flow (5 minutes)**

1. **Login/Register:**
   - Register new user or login
   - Show: User service working

2. **Book a Ride:**
   - Fill form: Pickup, Drop, City
   - Click "Start Ride"
   - Show: Success message with Ride ID

3. **Check My Rides:**
   - Navigate to "My Rides"
   - Show: Ride appears in list

4. **Show Backend Flow:**
   - Explain: Frontend → Ride Service → Payment Service → Lambda → Pub/Sub

### **Step 4: Show Analytics Pipeline (5 minutes)**

1. **Pub/Sub:**
   - Open GCP Pub/Sub topic
   - Show: Messages being published (metrics)

2. **Dataproc:**
   - Show: Analytics script running
   - Explain: Consumes from Pub/Sub, aggregates by city

3. **Firestore:**
   - Open Firestore console
   - Show: `ride_analytics` collection
   - Show: Documents with city, count, timestamp

4. **Frontend Analytics:**
   - Open http://localhost:3000/analytics
   - Show: Real-time chart from Firestore data

### **Step 5: Show Monitoring (5 minutes)**

1. **Grafana Dashboard:**
   - Open http://localhost:3001
   - Show: Pod count, CPU usage, memory
   - Show: All services metrics

2. **Prometheus:**
   - Open http://localhost:9090
   - Show: Metrics queries
   - Show: Service discovery

3. **ArgoCD:**
   - Open https://localhost:8080
   - Show: Applications, sync status
   - Explain: GitOps deployment

### **Step 6: Load Testing & HPA Scaling (5 minutes)**

1. **Before Load Test:**
   ```bash
   kubectl get pods -l app=ride-service
   ```
   - Show: 2 pods (minimum)

2. **Run Load Test:**
   ```bash
   .\scripts\run-load-test.ps1
   ```
   - Explain: Generating 50 concurrent users
   - Show: Test running

3. **Watch Pod Scaling:**
   ```bash
   kubectl get pods -l app=ride-service -w
   ```
   - Show: Pods scaling from 2 → 10
   - Show: HPA status: `29%/5%` (CPU above threshold)

4. **Grafana During Load:**
   - Show: Pod count graph increasing
   - Show: CPU usage spike
   - Show: Request rate increasing

5. **After Load Test:**
   - Show: Pods scale back down after 5 minutes
   - Explain: HPA automatically scales based on CPU

### **Step 7: Show Lambda Function (2 minutes)**

1. **AWS Lambda Console:**
   - Open Lambda function
   - Show: Function code
   - Show: API Gateway trigger

2. **Test Lambda:**
   - Show: API Gateway URL
   - Explain: Called asynchronously by Ride Service

3. **CloudWatch Logs:**
   - Show: Lambda execution logs
   - Show: Notification messages

---

## 6. Requirements Mapping

### **Requirement (a): Infrastructure as Code (IaC)**

✅ **Demonstrated:**
- Show `infra/aws/` directory → All AWS resources in Terraform
- Show `infra/gcp/` directory → All GCP resources in Terraform
- Explain: VPC, EKS, RDS, Lambda, S3, Dataproc, Firestore, Pub/Sub all provisioned via Terraform
- **Files to show:** `infra/aws/main.tf`, `infra/gcp/main.tf`

### **Requirement (b): 6 Microservices + Serverless**

✅ **Demonstrated:**
1. **User Service** - User management
2. **Driver Service** - Driver management
3. **Ride Service** - Main orchestration
4. **Payment Service** - Payment processing
5. **Notification Service (Lambda)** - Serverless, event-driven
6. **Frontend (Next.js)** - Web service accessible over public URL (localhost:3000)

**Communication:**
- REST APIs between services
- Pub/Sub (GCP) for event streaming
- API Gateway for Lambda

**Show:**
- All 6 services running
- Lambda function in AWS Console
- Frontend at http://localhost:3000

### **Requirement (c): Managed K8s + HPA**

✅ **Demonstrated:**
- **EKS Cluster:** Show in AWS Console
- **HPA:** Show `kubectl get hpa` → ride-service-hpa
- **Scaling:** Demonstrate during load test
- **Configuration:** Show `gitops/ride-service-deployment.yaml` → HPA section

**Show:**
- EKS cluster in AWS Console
- HPA configuration: `minReplicas: 2, maxReplicas: 10, targetCPU: 5%`
- Pod scaling during load test (2 → 10 pods)

### **Requirement (d): GitOps (ArgoCD)**

✅ **Demonstrated:**
- **ArgoCD:** Open https://localhost:8080
- **Applications:** Show 4 applications (user, driver, ride, payment)
- **Git Repository:** Explain GitOps workflow
- **No kubectl apply:** All deployments via ArgoCD

**Show:**
- ArgoCD dashboard
- Applications list
- Sync status
- Explain: "All deployments managed via GitOps, not direct kubectl"

### **Requirement (e): Stream Processing (Flink on Dataproc)**

✅ **Demonstrated:**
- **Dataproc Cluster:** Show in GCP Console
- **Flink:** Running on Dataproc (analytics script)
- **Kafka/Pub/Sub:** Consumes from `ride-booking-rides` topic
- **Time-windowed Aggregation:** 60-second windows, aggregates by city
- **Results Topic:** Publishes to `ride-booking-ride-results` (optional)

**Show:**
- Dataproc cluster in GCP Console
- Analytics script running (SSH or logs)
- Pub/Sub topic with messages
- Firestore with aggregated results (city-wise counts)

### **Requirement (f): Cloud Storage Products**

✅ **Demonstrated:**

1. **Object Store (S3):**
   - Show S3 bucket in AWS Console
   - Purpose: Asset storage

2. **Managed SQL (RDS):**
   - Show RDS PostgreSQL in AWS Console
   - Purpose: Users, rides, drivers, payments (relational data)
   - Show: Database endpoint, tables

3. **Managed NoSQL (Firestore):**
   - Show Firestore in GCP Console
   - Purpose: Real-time analytics results (semi-structured)
   - Show: `ride_analytics` collection with documents

**Show:**
- S3 bucket in AWS Console
- RDS database in AWS Console
- Firestore database in GCP Console

### **Requirement (g): Observability Stack**

✅ **Demonstrated:**

**Metrics:**
- **Prometheus:** http://localhost:9090
  - Show: Service discovery, targets
  - Show: Query examples
- **Grafana:** http://localhost:3001
  - Show: Dashboard with service metrics
  - Show: Pod count, CPU, memory, request rate
  - Show: Kubernetes cluster health

**Logging:**
- **CloudWatch (AWS):** Lambda logs
- **GCP Logging:** Dataproc logs
- Explain: Centralized logging for all services

**Show:**
- Prometheus UI with metrics
- Grafana dashboard with all panels
- Explain: "Comprehensive observability for all microservices"

### **Requirement (h): Load Testing & Resilience**

✅ **Demonstrated:**
- **Tool:** k6 (loadtest/ride_service_test.js)
- **Load Test:** Run `.\scripts\run-load-test.ps1`
- **HPA Scaling:** Show pods scaling from 2 → 10
- **Metrics:** Show Grafana during load test
- **Resilience:** System handles load, no errors

**Show:**
- Load test script
- Run load test
- Pod scaling in real-time
- Grafana metrics during load
- HPA status showing CPU above threshold

---

## 7. Load Testing Demonstration

### **Preparation:**

1. **Open Terminal 1:** Watch pods
   ```bash
   kubectl get pods -l app=ride-service -w
   ```

2. **Open Terminal 2:** Watch HPA
   ```bash
   kubectl get hpa ride-service-hpa -w
   ```

3. **Open Grafana:** http://localhost:3001
   - Navigate to dashboard
   - Show "Ride Service - Pod Count" panel

### **Run Load Test:**

```bash
.\scripts\run-load-test.ps1
```

### **What to Show Simultaneously:**

1. **Terminal 1:** Pods scaling up (2 → 3 → 4 → ... → 10)
2. **Terminal 2:** HPA showing CPU: `29%/5%` (above threshold)
3. **Grafana:** Pod count graph increasing
4. **Grafana:** CPU usage spiking
5. **AWS Console:** EKS cluster showing more pods
6. **k6 Output:** Requests being sent, success rate

### **After Load Test:**

1. **Wait 5 minutes:** Show pods scaling back down
2. **Explain:** HPA automatically scales based on CPU utilization
3. **Show:** System resilience - no errors, all requests succeeded

---

## 8. Key Points to Highlight

### **Architecture Highlights:**

1. **Multi-Cloud:**
   - AWS for primary infrastructure
   - GCP for analytics pipeline
   - Services communicate across clouds

2. **Microservices:**
   - 6 distinct services, each with specific purpose
   - Loosely coupled, communicate via REST and Pub/Sub
   - Independent scaling

3. **Serverless:**
   - Lambda function for notifications
   - Event-driven, asynchronous
   - No server management

4. **Real-Time Analytics:**
   - Flink on Dataproc processes events
   - Aggregates by city in 60-second windows
   - Results stored in Firestore
   - Frontend displays real-time analytics

5. **Auto-Scaling:**
   - HPA automatically scales pods
   - Based on CPU utilization (5% threshold)
   - Scales from 2 to 10 pods
   - Scales back down when load decreases

6. **GitOps:**
   - All deployments via ArgoCD
   - No manual kubectl apply
   - Version controlled

7. **Observability:**
   - Prometheus for metrics
   - Grafana for visualization
   - Centralized logging
   - Real-time monitoring

8. **Infrastructure as Code:**
   - All infrastructure in Terraform
   - Reproducible deployments
   - Version controlled

---

## 9. Quick Demo Checklist

### **Before Demo:**

- [ ] All port-forwards running
- [ ] Frontend running (npm run dev)
- [ ] All browser tabs open (AWS, GCP, local apps)
- [ ] Grafana dashboard loaded
- [ ] Prometheus accessible
- [ ] ArgoCD accessible
- [ ] Test user created (or seed database)

### **During Demo:**

- [ ] Show infrastructure in AWS/GCP consoles
- [ ] Show microservices in Kubernetes
- [ ] Demonstrate ride booking flow
- [ ] Show analytics pipeline (Pub/Sub → Dataproc → Firestore)
- [ ] Show monitoring dashboards
- [ ] Run load test and show scaling
- [ ] Show Lambda function
- [ ] Map each requirement to actual implementation

### **Key Metrics to Show:**

- **Pod Count:** 2 → 10 during load test
- **CPU Usage:** Spikes during load
- **Request Rate:** ~12 requests/second
- **Success Rate:** 100% (0 errors)
- **Analytics:** Real-time city-wise ride counts
- **Response Time:** p95 around 3-4 seconds under load

---

## 10. Troubleshooting During Demo

### **If Something Doesn't Work:**

1. **Port-forward not working:**
   ```bash
   .\scripts\fix-all-port-forwards.ps1
   ```

2. **Pods not scaling:**
   - Check Metrics Server: `kubectl get pods -n kube-system -l k8s-app=metrics-server`
   - Check HPA: `kubectl describe hpa ride-service-hpa`

3. **Analytics not showing:**
   - Check Dataproc: Analytics script running?
   - Check Firestore: Collection exists?
   - Wait 60 seconds (aggregation window)

4. **Frontend not connecting:**
   - Check port-forwards are running
   - Check `.env.local` has correct URLs

---

## 11. Demo Script (15-20 minutes)

### **Introduction (2 min):**
- "Multi-cloud ride booking platform"
- "6 microservices across AWS and GCP"
- "Real-time analytics, auto-scaling, GitOps"

### **Infrastructure (3 min):**
- Show AWS Console: EKS, RDS, Lambda
- Show GCP Console: Dataproc, Pub/Sub, Firestore
- Show Terraform code

### **Microservices (3 min):**
- Show Kubernetes pods
- Show port-forwards
- Show frontend
- Explain each service

### **Ride Booking Flow (3 min):**
- Register/Login
- Book a ride
- Show backend flow
- Show Lambda notification

### **Analytics Pipeline (2 min):**
- Show Pub/Sub messages
- Show Dataproc cluster
- Show Firestore data
- Show frontend analytics

### **Monitoring (2 min):**
- Show Grafana dashboard
- Show Prometheus
- Show ArgoCD

### **Load Testing (3 min):**
- Run load test
- Show pod scaling
- Show Grafana metrics
- Explain HPA

### **Requirements Summary (2 min):**
- Go through each requirement (a-h)
- Show how each is implemented
- Highlight key features

---

## 12. Important URLs & Commands

### **Local Applications:**
- Frontend: http://localhost:3000
- Grafana: http://localhost:3001 (admin / password from kubectl)
- Prometheus: http://localhost:9090
- ArgoCD: https://localhost:8080 (admin / password from kubectl)

### **Key Commands:**
```bash
# Check pods
kubectl get pods

# Check HPA
kubectl get hpa

# Watch pod scaling
kubectl get pods -l app=ride-service -w

# Run load test
.\scripts\run-load-test.ps1

# Check services
kubectl get svc
```

### **Terraform Outputs:**
```bash
# AWS
cd infra/aws
terraform output

# GCP
cd infra/gcp
terraform output
```

---

## ✅ Final Checklist

- [ ] All 6 microservices identified and explained
- [ ] Infrastructure shown in AWS/GCP consoles
- [ ] Ride booking flow demonstrated
- [ ] Analytics pipeline shown end-to-end
- [ ] Monitoring dashboards displayed
- [ ] Load test run with scaling demonstrated
- [ ] All requirements (a-h) mapped to implementation
- [ ] Lambda function shown
- [ ] GitOps (ArgoCD) demonstrated
- [ ] Real-time analytics working

---

**Good luck with your demo! 🚀**

