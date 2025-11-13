# Quick Redeployment Guide

## What to Skip on Second Deployment

If you've already deployed once and ran `terraform destroy`, here's what you **DON'T** need to do again:

---

## ❌ SKIP THESE STEPS (One-Time Setup Only)

### 1. Tool Installation ❌ SKIP
- Terraform, AWS CLI, Azure CLI, kubectl, Docker, Helm, k6, Node.js, Maven
- **Only install once per machine**

### 2. Cloud Credentials Configuration ❌ SKIP
```bash
# SKIP - Already configured
aws configure
az login
```
- **Only configure once** (unless credentials changed)
- Your credentials are saved in `~/.aws/credentials` and Azure CLI cache

### 3. Container Registry Creation ❌ SKIP
```bash
# SKIP - ECR repositories persist
aws ecr create-repository --repository-name user-service
aws ecr create-repository --repository-name driver-service
# etc...
```
- **ECR repositories are NOT destroyed by Terraform**
- They persist even after `terraform destroy`
- Only create once

### 4. Docker Image Build & Push ❌ SKIP (if code unchanged)
```bash
# SKIP if code hasn't changed
docker build -t ${REGISTRY}/user-service:latest .
docker push ${REGISTRY}/user-service:latest
```
- **Skip if your code hasn't changed**
- Images remain in registry after infrastructure is destroyed
- Only rebuild if you modified service code

### 5. Helm Repository Addition ❌ SKIP
```bash
# SKIP - Helm repos are cached locally
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
```
- **Only add once per machine**
- Helm caches repository information

### 6. Git Repository Setup ❌ SKIP
```bash
# SKIP - Repository already exists
git init
git remote add origin https://github.com/your-username/ride-booking-platform.git
```
- **Only do once**
- Your Git repo persists

### 7. Update Image References in Manifests ❌ SKIP
```yaml
# SKIP - Already updated
image: <REGISTRY>/user-service:latest
```
- **Only update once**
- Your gitops files already have correct registry URLs

---

## ✅ MUST DO EVERY TIME (After Terraform Destroy)

Here's the condensed list of steps you MUST repeat after `terraform destroy`:

---

## Quick Redeployment Checklist

### Phase 1: Infrastructure (15-20 minutes)

```bash
# 1. Deploy AWS Infrastructure
cd infra/aws
terraform apply
# Save outputs
terraform output rds_endpoint > ../../outputs/rds_endpoint.txt
terraform output api_gateway_url > ../../outputs/lambda_url.txt

# 2. Deploy Azure Infrastructure
cd ../azure
terraform apply
# Save outputs
terraform output eventhub_connection_string > ../../outputs/eventhub_conn.txt
terraform output cosmosdb_endpoint > ../../outputs/cosmos_endpoint.txt

# 3. Configure kubectl
aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1
kubectl get nodes  # Verify
```

### Phase 2: Kubernetes Configuration (2-3 minutes)

```bash
# 4. Create Database Secret
cd ../../
RDS_ENDPOINT=$(cd infra/aws && terraform output -raw rds_endpoint | cut -d':' -f1)
kubectl create secret generic db-credentials \
  --from-literal=host=${RDS_ENDPOINT} \
  --from-literal=name=ridebooking \
  --from-literal=user=admin \
  --from-literal=password=YourSecurePassword123!

# 5. Create Azure Secret
EVENTHUB_CONN=$(cd infra/azure && terraform output -raw eventhub_connection_string)
kubectl create secret generic azure-credentials \
  --from-literal=eventhub_connection_string="${EVENTHUB_CONN}"

# 6. Create ConfigMap
LAMBDA_URL=$(cd infra/aws && terraform output -raw api_gateway_url)
kubectl create configmap app-config \
  --from-literal=lambda_api_url="${LAMBDA_URL}"
```

### Phase 3: ArgoCD (3-5 minutes)

```bash
# 7. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 8. Get ArgoCD Password (save it!)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# 9. Port-forward ArgoCD (in separate terminal, keep running)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# 10. Deploy Applications
kubectl apply -f gitops/argocd-apps.yaml

# OR deploy directly without ArgoCD:
kubectl apply -f gitops/user-service-deployment.yaml
kubectl apply -f gitops/driver-service-deployment.yaml
kubectl apply -f gitops/ride-service-deployment.yaml
kubectl apply -f gitops/payment-service-deployment.yaml
```

### Phase 4: Monitoring (5-7 minutes)

```bash
# 11. Create monitoring namespace
kubectl create namespace monitoring

# 12. Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --timeout 10m

# 13. Install Loki
helm install loki grafana/loki-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true

# 14. Get Grafana Password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo ""

# 15. Port-forward Grafana (in separate terminal, keep running)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# 16. Import dashboard (via Grafana UI)
# Upload: monitoring/grafana/dashboards/ride-booking-dashboard.json
```

### Phase 5: Flink Job (5 minutes)

```bash
# 17. Rebuild Flink JAR (only if code changed)
cd analytics/flink-job
mvn clean package

# 18. Submit to HDInsight
# Via Azure Portal or CLI (see DEPLOYMENT.md for details)
```

### Phase 6: Frontend (2 minutes)

```bash
# 19. Update environment (if service URL changed)
cd ../../frontend/nextjs-ui

cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://localhost:8003
EOF

# 20. Start frontend (if not already running)
npm run dev
# Open: http://localhost:3000
```

### Phase 7: Port Forwards (keep running)

```bash
# Start all required port forwards in separate terminals:
kubectl port-forward svc/user-service 8001:80 &
kubectl port-forward svc/driver-service 8002:80 &
kubectl port-forward svc/ride-service 8003:80 &
kubectl port-forward svc/payment-service 8004:80 &
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
```

### Phase 8: Verify (2 minutes)

```bash
# Check everything is running
kubectl get pods
kubectl get hpa
kubectl get svc

# Test health endpoints
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
```

---

## Complete Automation Script

Save this as `redeploy.sh` for one-command redeployment:

```bash
#!/bin/bash
set -e

echo "🚀 Starting Redeployment..."

# Phase 1: Infrastructure
echo "📦 Deploying AWS Infrastructure..."
cd infra/aws
terraform apply -auto-approve
RDS_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d':' -f1)
LAMBDA_URL=$(terraform output -raw api_gateway_url)

echo "📦 Deploying Azure Infrastructure..."
cd ../azure
terraform apply -auto-approve
EVENTHUB_CONN=$(terraform output -raw eventhub_connection_string)
cd ../..

# Phase 2: Kubernetes Setup
echo "⚙️  Configuring kubectl..."
aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1

echo "🔐 Creating Secrets..."
kubectl create secret generic db-credentials \
  --from-literal=host=${RDS_ENDPOINT} \
  --from-literal=name=ridebooking \
  --from-literal=user=admin \
  --from-literal=password=YourSecurePassword123!

kubectl create secret generic azure-credentials \
  --from-literal=eventhub_connection_string="${EVENTHUB_CONN}"

kubectl create configmap app-config \
  --from-literal=lambda_api_url="${LAMBDA_URL}"

# Phase 3: ArgoCD
echo "🔄 Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🔑 ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "📝 Deploying Applications..."
kubectl apply -f gitops/argocd-apps.yaml

# Phase 4: Monitoring
echo "📊 Installing Monitoring Stack..."
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --timeout 10m

helm install loki grafana/loki-stack \
  -n monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true

echo "🔑 Grafana Password:"
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo ""

# Phase 5: Frontend
echo "🌐 Configuring Frontend..."
cd frontend/nextjs-ui
cat > .env.local << EOF
NEXT_PUBLIC_API_BASE_URL=http://localhost:8003
EOF
cd ../..

echo "✅ Redeployment Complete!"
echo ""
echo "📝 Next Steps:"
echo "1. Start port forwards:"
echo "   kubectl port-forward svc/ride-service 8003:80"
echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Submit Flink job to HDInsight (see DEPLOYMENT.md)"
echo ""
echo "3. Start frontend:"
echo "   cd frontend/nextjs-ui && npm run dev"
echo ""
echo "4. Access services:"
echo "   - Frontend: http://localhost:3000"
echo "   - Grafana: http://localhost:3000 (different port forward)"
echo "   - ArgoCD: https://localhost:8080"
```

Make it executable:
```bash
chmod +x redeploy.sh
./redeploy.sh
```

---

## Time Comparison

| Phase | First Time | Second Time |
|-------|-----------|-------------|
| Prerequisites | 30-60 min | ❌ **0 min (skip)** |
| Build Docker Images | 10-15 min | ❌ **0 min (skip if unchanged)** |
| Terraform Apply | 35-50 min | ✅ **35-50 min (required)** |
| K8s Configuration | 5 min | ✅ **5 min (required)** |
| ArgoCD | 5 min | ✅ **5 min (required)** |
| Monitoring | 10 min | ✅ **10 min (required)** |
| Flink | 5 min | ✅ **5 min (required)** |
| Frontend | 5 min | ✅ **2 min (required)** |
| **Total** | **105-150 min** | **✅ 62-77 min** |

**You save ~40-70 minutes on redeployment!**

---

## What Gets Destroyed by `terraform destroy`?

### ✅ Destroyed (Must Recreate):
- EKS cluster
- RDS database (including all data!)
- Lambda function
- API Gateway
- S3 bucket (if not versioned/protected)
- Event Hub namespace
- HDInsight cluster
- Cosmos DB account (including all data!)
- VPCs, subnets, security groups
- All Kubernetes resources (pods, services, secrets, configmaps)

### ❌ NOT Destroyed (Persist):
- ECR repositories and Docker images
- Your local code and Git repository
- Helm repository cache
- AWS/Azure credentials
- Terraform state files (if using local backend)
- Your laptop installations (tools)

---

## Important Notes

### ⚠️ Data Loss Warning
`terraform destroy` **DESTROYS ALL DATA** in:
- RDS PostgreSQL database
- Cosmos DB
- Any data in S3 buckets

**To preserve data:** Export databases before destroying:
```bash
# Export RDS data
pg_dump -h <RDS_ENDPOINT> -U admin -d ridebooking > backup.sql

# Export Cosmos DB data
# Use Azure Portal or mongodump
```

### ⚠️ Kubernetes Resources
All Kubernetes resources (pods, services, secrets, configmaps) are stored in the EKS cluster, so they're destroyed when you run `terraform destroy` on AWS infrastructure.

**You MUST recreate:**
- All secrets (db-credentials, azure-credentials)
- All configmaps (app-config)
- All deployments (unless using ArgoCD to sync from Git)
- ArgoCD itself
- Monitoring stack

### ⚠️ Cost Considerations
Even after `terraform destroy`, you might still be charged for:
- ECR storage (Docker images)
- S3 versioned objects
- CloudWatch logs
- Azure storage accounts (if not deleted)

**To completely clean up:**
```bash
# Delete ECR repositories
aws ecr delete-repository --repository-name user-service --force
aws ecr delete-repository --repository-name driver-service --force
aws ecr delete-repository --repository-name ride-service --force
aws ecr delete-repository --repository-name payment-service --force

# Delete CloudWatch logs
aws logs delete-log-group --log-group-name /aws/lambda/ride-booking-notification-lambda
```

---

## Quick Command Reference

```bash
# Check what needs to be done
kubectl get nodes              # If this fails, run terraform apply
kubectl get pods               # If this fails, deploy services
kubectl get hpa                # If this fails, check HPA configuration

# Start from scratch
terraform destroy              # Destroy everything
./redeploy.sh                  # Redeploy everything

# Manual verification
kubectl get all                # Check all resources
kubectl get secrets            # Check secrets exist
kubectl get configmaps         # Check configmaps exist
```

---

## Troubleshooting Redeployment

### Issue: kubectl cannot connect to cluster
**Solution:** Re-run kubectl configuration
```bash
aws eks update-kubeconfig --name ride-booking-eks --region ap-south-1
```

### Issue: Secrets already exist
**Solution:** Delete old secrets first
```bash
kubectl delete secret db-credentials
kubectl delete secret azure-credentials
kubectl delete configmap app-config
# Then recreate them
```

### Issue: ArgoCD namespace already exists
**Solution:** Clean up previous installation
```bash
kubectl delete namespace argocd --wait=false
# Wait a minute, then reinstall
```

### Issue: Helm release already exists
**Solution:** Uninstall old releases
```bash
helm uninstall prometheus -n monitoring
helm uninstall loki -n monitoring
# Then reinstall
```

---

## Summary

**SKIP on second deployment:**
- ❌ Installing tools
- ❌ Configuring credentials
- ❌ Creating ECR repositories
- ❌ Building/pushing Docker images (if code unchanged)
- ❌ Adding Helm repositories
- ❌ Setting up Git repository
- ❌ Updating manifest image references

**MUST DO on second deployment:**
- ✅ Terraform apply (AWS + Azure)
- ✅ Configure kubectl
- ✅ Create Kubernetes secrets & configmaps
- ✅ Install ArgoCD
- ✅ Deploy services
- ✅ Install monitoring stack
- ✅ Submit Flink job
- ✅ Configure & start frontend

**Total time saved:** ~40-70 minutes!

---

**Pro Tip:** Use the `redeploy.sh` script for one-command redeployment! 🚀

