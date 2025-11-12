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

## Demo Flow (10-15 minutes)

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

### 7. Analytics Dashboard (1 minute)

**Script:**
> "The ride events are processed by our Flink job on Azure HDInsight, which aggregates rides per city per minute and stores results in Cosmos DB."

**Actions:**
1. Navigate to `/analytics`
2. Show analytics dashboard with charts

**Show:**
- Analytics dashboard
- Bar chart showing rides per city
- Data from Cosmos DB

**Script:**
> "The analytics are updated in real-time as rides are processed. The Flink job consumes events from Event Hub, aggregates them, and writes to Cosmos DB."

---

### 8. Observability - Grafana (1 minute)

**Script:**
> "Let's check our observability stack. We have Prometheus collecting metrics and Grafana displaying dashboards."

**Actions:**
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

1. Open Grafana: `http://localhost:3000`
2. Show dashboards:
   - CPU usage per service
   - HPA pod scaling
   - Request rate

**Show:**
- Grafana dashboards
- Metrics from Prometheus
- Current pod counts

**Script:**
> "Grafana provides real-time visibility into our system's performance, including CPU usage, request rates, and pod scaling."

---

### 9. Load Testing and HPA Scaling (3 minutes)

**Script:**
> "Now let's demonstrate horizontal pod autoscaling by running a load test. We'll use k6 to generate traffic and watch the pods scale automatically."

**Actions:**
```bash
# Disable notifications during load test
export DISABLE_NOTIFICATIONS=true

# Show HPA before load test
kubectl get hpa

# Show current pod count
kubectl get pods -l app=ride-service

# Run load test in one terminal
k6 run loadtest/ride_service_test.js

# In another terminal, watch pods scale
kubectl get pods -l app=ride-service -w
```

**Show:**
- k6 load test output
- Pod count increasing (2 → 4 → 6 → 8)
- HPA status showing scaling
- Grafana dashboard showing CPU spike and scaling

**Script:**
> "As the load increases, the HPA detects high CPU utilization and automatically scales up the Ride Service pods. You can see the pod count increasing from 2 to 8 pods. Once the load decreases, it will scale back down."

**Actions:**
```bash
# After load test, show scaling down
kubectl get hpa
kubectl get pods -l app=ride-service
```

**Show:**
- Pods scaling down
- HPA metrics returning to normal

---

### 10. Summary and Requirements (1 minute)

**Script:**
> "Let me summarize what we've demonstrated:"

**Show checklist:**
- ✅ Infrastructure as Code (Terraform)
- ✅ 6 Microservices (4 EKS + 1 Lambda + 1 Flink)
- ✅ Multi-cloud (AWS + Azure)
- ✅ Serverless function (Lambda)
- ✅ Stream processing (Flink)
- ✅ GitOps (ArgoCD)
- ✅ Kubernetes autoscaling (HPA)
- ✅ Observability (Prometheus + Grafana + Loki)
- ✅ Distinct storage types (RDS + Cosmos DB + S3)
- ✅ Load testing (k6)

**Script:**
> "All requirements for the BITS Cloud Computing project have been satisfied. The platform demonstrates modern cloud-native patterns including microservices, serverless computing, stream processing, and infrastructure automation."

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
   - Use clear, readable terminal fonts
   - Zoom in on important outputs
   - Show both terminal and browser windows

2. **Narration:**
   - Speak clearly and at moderate pace
   - Explain what you're doing before doing it
   - Pause after showing important outputs

3. **Timing:**
   - Keep demo under 15 minutes
   - Skip non-essential steps if running long
   - Focus on key requirements

4. **Preparation:**
   - Practice the demo once before recording
   - Have all commands ready in a text file
   - Test all services before recording

---

## Success Criteria

✅ All 10 requirements demonstrated
✅ Services responding correctly
✅ HPA scaling visible
✅ Analytics showing data
✅ Grafana dashboards functional
✅ Load test completes successfully
✅ Clear narration and explanation

**Good luck with your demo! 🚀**

