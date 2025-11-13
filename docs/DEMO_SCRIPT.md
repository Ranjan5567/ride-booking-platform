# Demo Script for Ride Booking Platform

This script provides a step-by-step guide for demonstrating the Ride Booking Platform for the BITS Cloud Computing project video recording.

## Pre-Demo Setup (Before Recording)

1. **Infrastructure Deployed**
   - AWS infrastructure via Terraform
   - Azure infrastructure via Terraform
   - EKS cluster accessible
   - All services deployed

2. **Environment Ready**
   - kubectl configured
   - AWS CLI configured
   - Azure CLI configured
   - Frontend running locally or deployed

3. **Credentials Available**
   - Database credentials
   - Event Hub connection string
   - API Gateway URL

---

## Demo Flow (15-18 minutes)

**Timing Breakdown:**
- Introduction: 30 seconds
- Infrastructure (Terraform): 1 minute
- GitOps (ArgoCD): 1 minute
- Microservices Overview: 1 minute
- User Registration: 1 minute
- Ride Booking (Integration): 2 minutes
- Stream Processing & Analytics: 2 minutes
- Storage Types: 1 minute
- Observability Setup: 1 minute
- Load Testing + HPA + Grafana: 4 minutes
- Summary & Requirements: 1 minute
- **Total: 15.5 minutes**

### 1. Introduction (30 seconds)

**Script:**
> "Welcome to the Ride Booking Platform demonstration. This is a multi-cloud, microservices-based system built for the BITS Cloud Computing course. The platform demonstrates Infrastructure as Code, GitOps, serverless functions, stream analytics, and Kubernetes autoscaling."

**Show:**
- Project structure overview
- Architecture diagram

---

### 2. Infrastructure as Code (1 minute)

**Script:**
> "All infrastructure is provisioned using Terraform. We have separate modules for AWS and Azure."

**Actions:**
```bash
# Show Terraform files
cd infra/aws
ls -la
cat main.tf | head -20

cd ../azure
ls -la
cat main.tf | head -20
```

**Show:**
- Terraform module structure
- Key resources (EKS, RDS, Event Hub, HDInsight)

**Script:**
> "The infrastructure includes VPC, EKS cluster, RDS database on AWS, and Event Hub, HDInsight Flink, and Cosmos DB on Azure."

---

### 3. GitOps with ArgoCD (1 minute)

**Script:**
> "Application deployments are managed via GitOps using ArgoCD. All services are automatically synced from the Git repository."

**Actions:**
```bash
# Show ArgoCD UI or CLI
kubectl get applications -n argocd
argocd app list

# Show GitOps manifests
cat gitops/argocd-apps.yaml
```

**Show:**
- ArgoCD dashboard (if accessible)
- Application sync status
- Git repository connection

**Script:**
> "ArgoCD monitors our Git repository and automatically deploys any changes. This ensures consistency and enables easy rollbacks."

---

### 4. Microservices Overview (1 minute)

**Script:**
> "We have 6 microservices: 4 running on EKS, 1 Lambda function, and 1 Flink job on Azure."

**Actions:**
```bash
# Show running services
kubectl get deployments
kubectl get services

# Show Lambda
aws lambda list-functions --query 'Functions[?contains(FunctionName, `notification`)]'
```

**Show:**
- Running pods in EKS
- Service endpoints
- Lambda function details

**Script:**
> "The services are containerized and deployed on Kubernetes. Each service has its own database schema and API endpoints."

---

### 5. Frontend - User Registration (1 minute)

**Script:**
> "Let's start by registering a new user through the frontend."

**Actions:**
1. Open frontend in browser: `http://localhost:3000`
2. Navigate to `/auth`
3. Fill registration form:
   - Name: "John Doe"
   - Email: "john@example.com"
   - Password: "password123"
   - User Type: "Rider"
   - City: "Bangalore"
4. Click "Register"

**Show:**
- Registration form
- Success message
- User stored in database

**Script:**
> "The user is now registered and stored in our RDS PostgreSQL database. The User Service handles this operation."

---

### 6. Frontend - Book a Ride (2 minutes)

**Script:**
> "Now let's book a ride. This will trigger multiple services: Ride Service, Payment Service, Lambda notification, and event publishing to Azure."

**Actions:**
1. Navigate to `/book`
2. Fill ride form:
   - Pickup: "Koramangala"
   - Drop: "HSR Layout"
   - City: "Bangalore"
   - Driver ID: 1
3. Click "Start Ride"

**Show:**
- Ride booking form
- Success response with ride ID
- Network tab showing API calls

**Script:**
> "When we book a ride, the Ride Service orchestrates multiple operations:
> 1. Stores the ride in RDS
> 2. Calls the Payment Service (which returns SUCCESS instantly)
> 3. Triggers the Lambda notification function
> 4. Publishes an event to Azure Event Hub"

**Actions:**
```bash
# Show Lambda logs
aws logs tail /aws/lambda/ride-booking-notification-lambda --follow

# Show ride in database (if accessible)
# Or show in frontend /rides page
```

**Show:**
- Lambda CloudWatch logs
- Ride stored in database
- Event published to Event Hub (if visible)

---

### 7. Stream Processing and Analytics (2 minutes)

**Script:**
> "Now let's demonstrate our real-time stream processing pipeline. Every ride we book publishes an event to Azure Event Hub, which is processed by a Flink job running on HDInsight."

**Step 1: Show Event Hub Activity**

**Actions:**
```bash
# Show Event Hub metrics via Azure CLI
az eventhubs eventhub show \
  --resource-group ride-booking-rg \
  --namespace-name ride-booking-eh-namespace \
  --name rides \
  --query "{Name:name, PartitionCount:partitionCount, Status:status}" \
  --output table
```

**Show in Azure Portal:**
1. Navigate to Event Hub namespace
2. Open "rides" event hub
3. Show "Overview" → Metrics
4. Display "Incoming Messages" graph
5. Show message throughput

**Script:**
> "Here's our Azure Event Hub receiving ride events. Each ride booking publishes a JSON event containing ride details like city, pickup, drop location."

---

**Step 2: Show Flink Job Processing**

**Access HDInsight Flink UI:**
```bash
# Get cluster endpoint
cd infra/azure
terraform output hdinsight_cluster_name
# Access at: https://<cluster-name>.azurehdinsight.net
```

**Show in Flink UI:**
1. Navigate to HDInsight cluster dashboard
2. Open Apache Flink UI
3. Show running job: "RideAnalyticsJob"
4. Display job metrics:
   - Records processed
   - Processing rate (records/second)
   - Throughput
5. Show job topology/dataflow

**Script:**
> "Our Flink job is continuously processing events. It performs stateful aggregation using 1-minute tumbling windows, counting rides per city. This is real-time stream processing at scale."

---

**Step 3: Show Aggregated Results in Cosmos DB**

**Show in Azure Portal:**
1. Navigate to Cosmos DB account
2. Go to "Data Explorer"
3. Select "analytics" database
4. Select "ride_analytics" collection
5. Run query:
```javascript
db.ride_analytics.find().sort({timestamp: -1}).limit(10)
```

**Show document structure:**
```json
{
  "_id": "...",
  "city": "Bangalore",
  "count": 45,
  "window_start": "2024-01-15T10:30:00Z",
  "window_end": "2024-01-15T10:31:00Z",
  "timestamp": "2024-01-15T10:31:00Z"
}
```

**Script:**
> "The Flink job writes aggregated results to Cosmos DB. Each document represents the ride count for a specific city within a 1-minute window. This NoSQL database provides high-throughput storage for analytics."

---

**Step 4: Show Analytics Dashboard**

**Actions:**
1. Navigate to frontend: `http://localhost:3000/analytics`
2. Show analytics dashboard with charts

**Show:**
- Bar chart: Rides per city
- Line graph: Rides over time (if implemented)
- Top cities table
- Real-time update indicator

**Script:**
> "The frontend queries this analytics data from Cosmos DB and displays it in interactive charts. This completes our stream processing pipeline: Event Hub → Flink → Cosmos DB → Frontend."

---

**Step 5: Demonstrate Real-Time Update (Optional)**

**Actions:**
```bash
# Book multiple rides in quick succession
curl -X POST http://localhost:8003/ride/start \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": 1,
    "driver_id": 1,
    "pickup": "Koramangala",
    "drop": "HSR Layout",
    "city": "Mumbai"
  }'

# Book another
curl -X POST http://localhost:8003/ride/start \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": 1,
    "driver_id": 1,
    "pickup": "Bandra",
    "drop": "Andheri",
    "city": "Mumbai"
  }'

# Refresh analytics dashboard after 1 minute
```

**Show:**
- Event Hub showing new messages
- Flink processing metrics increasing
- Cosmos DB updated with new window
- Analytics dashboard reflecting new data

**Script:**
> "Watch how quickly the pipeline processes new data. Within one minute, the aggregated results appear in our dashboard. This is production-grade real-time analytics."

---

### 8. Storage Types Demonstration (1 minute)

**Script:**
> "Our system uses three distinct cloud storage types, each optimized for different use cases."

**Actions:**
```bash
# Show RDS PostgreSQL (relational data)
cd infra/aws
terraform output rds_endpoint

# Show Cosmos DB (NoSQL for analytics)
cd ../azure
terraform output cosmosdb_endpoint

# Show S3 bucket (object storage)
cd ../aws
terraform output s3_bucket_name
```

**Show:**
- AWS Console: RDS database with users, drivers, rides tables
- Azure Portal: Cosmos DB with analytics collection
- AWS Console: S3 bucket

**Script:**
> "We use RDS PostgreSQL for transactional data like users and rides, Cosmos DB for high-throughput analytics results, and S3 for object storage. This demonstrates proper use of different storage types for different data patterns."

---

### 9. Observability Stack Setup (1 minute)

**Script:**
> "Before we run the load test, let's set up our observability dashboard. We have Prometheus collecting metrics and Grafana displaying real-time dashboards."

**Actions:**
```bash
# Port forward Grafana (keep this running)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Get Grafana password if needed
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

1. Open Grafana: `http://localhost:3000`
2. Login with admin credentials
3. Navigate to "Ride Booking Platform Dashboard"
4. Show panels:
   - CPU usage per service (currently low)
   - HPA pod scaling (currently at 2 replicas)
   - Request rate (currently minimal)
   - Error rate

**Show:**
- Grafana dashboard with all panels visible
- Current baseline metrics (low CPU, 2 pods)
- Prometheus data source connected

**Script:**
> "Grafana provides real-time visibility into our system. Notice the CPU is currently low and we have 2 pods running. We'll watch this dashboard change in real-time during the load test."

---

### 10. Load Testing with Real-Time HPA Scaling and Monitoring (4 minutes)

**Script:**
> "Now for the most impressive demonstration - horizontal pod autoscaling with real-time monitoring. We'll run a load test with k6 and watch the system automatically scale up while monitoring everything in Grafana."

**Setup (show split screen):**
- **Left side:** Terminal with kubectl commands
- **Right side:** Grafana dashboard in browser

**Step 1: Show Initial State**

```bash
# Show HPA status before load test
kubectl get hpa
# Expected: ride-service-hpa at 0-30% CPU, 2/2 pods

# Show current pod count
kubectl get pods -l app=ride-service
# Expected: 2 pods running

# Disable notifications for cleaner test
kubectl set env deployment/ride-service DISABLE_NOTIFICATIONS=true
kubectl rollout status deployment/ride-service
```

**Show in Grafana:**
- CPU Usage panel: ~10-20% (low)
- HPA Pod Count panel: 2 replicas
- Request Rate panel: minimal traffic
- Error Rate panel: 0 errors

**Script:**
> "Notice we start with 2 pods at low CPU utilization. The HPA is configured to scale when CPU exceeds 70%."

---

**Step 2: Start Load Test**

```bash
# Terminal 1: Run load test
cd loadtest
k6 run ride_service_test.js

# Terminal 2: Watch HPA in real-time
watch -n 2 kubectl get hpa

# Terminal 3: Watch pods scale
watch -n 2 "kubectl get pods -l app=ride-service"
```

**Script:**
> "I'm starting the k6 load test which will ramp up to 50 virtual users. Watch the Grafana dashboard - you'll see CPU usage spike in real-time."

**Show simultaneously:**

**In Grafana (switch to browser):**
- CPU Usage panel: Shows spike from 20% → 50% → 80%+ (within 30 seconds)
- Request Rate panel: Shows dramatic increase
- HPA Pod Count panel: Still at 2 (takes ~1 minute to trigger)

**In Terminal (switch back):**
- k6 output showing increasing request rate
- kubectl showing CPU rising above 70%

**Script:**
> "See the CPU usage climbing rapidly! It's now above the 70% threshold. The HPA will detect this and start scaling."

---

**Step 3: Observe Scaling (1-2 minutes)**

**In Terminal:**
```bash
# Watch HPA show scaling decision
kubectl get hpa ride-service-hpa
# Shows: TARGETS: 85%/70%, REPLICAS: 4/10

# Watch new pods being created
kubectl get pods -l app=ride-service -w
# Shows: New pods in ContainerCreating → Running
```

**Show in Grafana:**
- HPA Pod Count panel: 2 → 3 → 4 → 6 → 8 (over 2 minutes)
- CPU Usage panel: Initially high, then drops as pods distribute load
- Request Rate panel: Sustained high throughput
- Error Rate panel: Remains low (<5%)

**Script:**
> "Excellent! The HPA detected high CPU and is scaling up. We now have 4 pods... 6 pods... and now 8 pods. Notice how the CPU per pod drops as the load distributes across more instances. This is automatic horizontal scaling in action!"

---

**Step 4: Show Sustained Performance**

**Actions:**
```bash
# Show all scaled pods handling load
kubectl get pods -l app=ride-service
# Expected: 8 pods, all Running

# Show HPA satisfied
kubectl get hpa
# Expected: CPU ~60-70%, 8/10 replicas

# Show detailed HPA metrics
kubectl describe hpa ride-service-hpa
```

**Show in Grafana:**
- CPU Usage: Stabilized at ~60-70% across all pods
- Pod Count: Holding steady at 8
- Request Rate: Consistent high throughput
- Error Rate: Low (<5%)

**Script:**
> "The system has stabilized with 8 pods efficiently handling the load. The CPU is now at a healthy 60-70%, and error rates remain minimal. This demonstrates production-ready autoscaling."

---

**Step 5: Load Test Completion & Scale Down**

**Script:**
> "The load test is completing. Watch as the traffic decreases and the HPA scales back down."

**Show in k6:**
- Test completing, VUs ramping down
- Final summary statistics

**Show in Grafana (over next 5 minutes):**
- Request Rate panel: Declining
- CPU Usage panel: Dropping to 30-40%
- HPA Pod Count panel: Will scale down after cooldown period (5 minutes)

**Actions:**
```bash
# Show HPA recognizing lower CPU
kubectl get hpa -w
# Wait 2-3 minutes, show CPU dropping below threshold

# Eventually show scale down (may need to fast-forward in demo)
kubectl get pods -l app=ride-service
# Expected: Scaling back to 2 pods
```

**Script:**
> "After the cooldown period, the HPA scales back down to conserve resources. This demonstrates both scale-up and scale-down automation."

---

**Step 6: Show Prometheus Metrics (Optional but Impressive)**

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090
```

**Show Prometheus queries:**
```promql
# CPU usage query
rate(container_cpu_usage_seconds_total{pod=~"ride-service.*"}[5m])

# Replica count over time
kube_deployment_status_replicas{deployment="ride-service"}
```

**Show graphs:** Historical view of the scaling event

**Script:**
> "Prometheus stores all these metrics. We can query historical data to see the complete scaling event timeline."

---

### 11. Summary and Requirements Checklist (1 minute)

**Script:**
> "Let me summarize everything we've demonstrated against the project requirements."

**Show Requirements Checklist (display on screen or in document):**

**Requirement (a): Infrastructure as Code ✅**
- ✅ All infrastructure provisioned via Terraform
- ✅ Separate modules for AWS and Azure
- ✅ Network, clusters, databases, storage, IAM policies
- **Demo:** Showed Terraform files, modules, and outputs

**Requirement (b): 6 Microservices + Multi-Cloud ✅**
- ✅ User Service (FastAPI on EKS)
- ✅ Driver Service (FastAPI on EKS)
- ✅ Ride Service (FastAPI on EKS - orchestrator)
- ✅ Payment Service (FastAPI on EKS)
- ✅ Notification Service (AWS Lambda - serverless)
- ✅ Analytics Service (Flink on Azure HDInsight - different cloud)
- ✅ Domain: Transportation/Ride Booking
- ✅ Communication: REST APIs + Event Hub (Kafka-compatible)
- **Demo:** Showed all 6 services running, Lambda logs, Flink job

**Requirement (c): Managed Kubernetes + HPA ✅**
- ✅ AWS EKS cluster hosting 4 microservices
- ✅ HPA on Ride Service (scaled 2 → 8 pods)
- ✅ HPA on User Service (configured)
- ✅ CPU-based autoscaling (70% threshold)
- **Demo:** Live load test showing automatic scaling

**Requirement (d): GitOps ✅**
- ✅ ArgoCD deployed and managing deployments
- ✅ Auto-sync from Git repository
- ✅ No direct kubectl apply for deployments
- **Demo:** Showed ArgoCD applications and sync status

**Requirement (e): Stream Processing with Flink ✅**
- ✅ Flink job on Azure HDInsight (Provider B)
- ✅ Consumes from Azure Event Hub (Kafka-compatible)
- ✅ Stateful time-windowed aggregation (1-minute windows)
- ✅ Counts rides per city per window
- ✅ Writes results to Cosmos DB
- ✅ Managed Kafka service (Event Hub)
- **Demo:** Showed Event Hub metrics, Flink UI, Cosmos DB results

**Requirement (f): Distinct Storage Products ✅**
- ✅ Object Store: AWS S3 (for assets/logs)
- ✅ Managed SQL: AWS RDS PostgreSQL (users, rides)
- ✅ Managed NoSQL: Azure Cosmos DB (analytics results)
- **Demo:** Showed all three storage types with data

**Requirement (g): Observability Stack ✅**
- ✅ Prometheus deployed and collecting metrics
- ✅ Grafana dashboard with:
  - Service metrics (CPU, memory)
  - Request rate
  - Error rate
  - Kubernetes cluster health
  - HPA pod scaling
- ✅ Loki for centralized logging
- **Demo:** Live Grafana monitoring during load test

**Requirement (h): Load Testing ✅**
- ✅ k6 load testing tool
- ✅ Sustained traffic generation (50 VUs)
- ✅ Demonstrated HPA scaling (2 → 8 pods)
- ✅ Real-time monitoring in Grafana
- ✅ System resilience validated
- **Demo:** Complete load test with live metrics

**Additional Features (Bonus):**
- ✅ Public web service (Next.js frontend)
- ✅ Complete documentation
- ✅ End-to-end integration working

**Script:**
> "All requirements for the BITS Cloud Computing project have been fully satisfied. The platform demonstrates modern cloud-native patterns including microservices, serverless computing, stream processing, infrastructure automation, and production-grade observability. This is a complete, functional multi-cloud application."

---

## Troubleshooting During Demo

### If services are not responding:
```bash
kubectl get pods
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

### If HPA is not scaling:
```bash
kubectl get hpa
kubectl describe hpa ride-service-hpa
# Check if metrics server is installed
kubectl get apiservice v1beta1.metrics.k8s.io
```

### If Event Hub connection fails:
- Check connection string format
- Verify network connectivity from EKS to Azure
- Check Event Hub namespace and topic exist

### If Grafana is not accessible:
```bash
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

---

## Post-Demo Cleanup (Optional)

```bash
# Scale down services
kubectl scale deployment ride-service --replicas=2

# Stop load test if still running
# Ctrl+C in k6 terminal
```

---

## Key Talking Points

1. **Multi-cloud architecture** - Show how AWS and Azure work together
2. **GitOps** - Emphasize automatic deployments from Git
3. **Autoscaling** - Highlight automatic scaling during load test
4. **Observability** - Show real-time metrics and dashboards
5. **Stream processing** - Explain event-driven analytics
6. **Serverless** - Show Lambda function execution

---

## Recording Tips

1. **Screen Recording:**
   - Use clear, readable terminal fonts (14pt minimum)
   - Zoom in on important outputs (Ctrl/Cmd + for browsers)
   - Use split screen for simultaneous views (terminal + Grafana)
   - Record at 1080p minimum resolution
   - Use OBS Studio or similar for professional recording

2. **Narration:**
   - Speak clearly and at moderate pace
   - Explain what you're doing before doing it
   - Pause 2-3 seconds after showing important outputs
   - Don't rush - clarity over speed
   - Emphasize key requirement demonstrations

3. **Timing:**
   - Keep demo at 15-18 minutes (requirement-focused)
   - Have a backup plan if something fails
   - Pre-book 2-3 rides before recording for analytics demo
   - Consider recording sections separately and editing together

4. **Preparation Checklist:**
   - [ ] Practice the demo 2-3 times before recording
   - [ ] Have all commands in a text file for copy-paste
   - [ ] Test all services 30 minutes before recording
   - [ ] Pre-populate database with 1-2 test users/drivers
   - [ ] Clear browser cache and terminal history
   - [ ] Close unnecessary applications
   - [ ] Set "Do Not Disturb" mode
   - [ ] Check audio levels
   - [ ] Ensure stable internet connection
   - [ ] Have Grafana dashboard already open
   - [ ] Position windows for screen recording

5. **Pro Tips:**
   - Keep a glass of water nearby
   - Have the DEMO_SCRIPT.md open on second monitor
   - Use keyboard shortcuts to switch between windows smoothly
   - If something fails, have a backup recording of that section
   - Record 2-3 takes and choose the best one

---

## Success Criteria

### Must-Have Demonstrations:
✅ All infrastructure via Terraform (shown)
✅ All 6 microservices identified and working
✅ Multi-cloud architecture (AWS + Azure) demonstrated
✅ Serverless function (Lambda) logs shown
✅ Stream processing (Flink) with Event Hub → Cosmos DB
✅ GitOps with ArgoCD (auto-sync demonstrated)
✅ HPA scaling 2 → 8 pods during load test
✅ Real-time Grafana monitoring during scaling
✅ Three storage types (RDS, Cosmos DB, S3) shown
✅ Complete load test with k6

### Nice-to-Have (If Time Permits):
✅ Database queries showing actual data
✅ ArgoCD UI showing sync status
✅ Prometheus queries
✅ Loki log aggregation
✅ Frontend end-to-end user flow
✅ Scale-down demonstration

### Video Quality Criteria:
✅ Clear audio throughout
✅ Readable text (terminals and browser)
✅ Smooth transitions between sections
✅ No dead silence (keep narrating)
✅ Professional presentation
✅ 15-18 minute duration

### Scoring Rubric Alignment:
- **Infrastructure (10M):** Terraform modules, multi-cloud ✅
- **Microservices (10M):** All 6 services demonstrated ✅
- **GitOps (5M):** ArgoCD deployment and sync ✅
- **Stream Processing (10M):** Flink job with Event Hub ✅
- **Autoscaling (5M):** Live HPA demonstration ✅
- **Observability (10M):** Grafana with real-time monitoring ✅
- **Load Testing (5M):** k6 with sustained traffic ✅
- **Integration (5M):** End-to-end flow working ✅
- **Total: 60M**

---

## Emergency Backup Plan

If something fails during recording:

**If services crash:**
- Have kubectl commands ready to check logs quickly
- Explain it's a demo environment, restart deployment
- Continue with other sections

**If HPA doesn't scale:**
- Show HPA configuration and explain the mechanism
- Show Grafana metrics increasing
- Use previous recording of successful scaling

**If Event Hub/Flink fails:**
- Show Azure Portal metrics
- Explain the architecture with diagrams
- Show Cosmos DB with pre-populated data

**If Grafana is empty:**
- Use Prometheus directly
- Show kubectl top nodes/pods
- Explain metrics collection is working

---

## Post-Recording Checklist

After recording:
- [ ] Watch the entire video
- [ ] Verify audio is clear throughout
- [ ] Check all requirements are demonstrated
- [ ] Add timestamps in video description (optional)
- [ ] Upload to YouTube/Google Drive
- [ ] Set appropriate permissions (unlisted or public)
- [ ] Test video link works
- [ ] Add link to demo_video.txt
- [ ] Commit and push to repository

---

**Good luck with your demo! 🚀**