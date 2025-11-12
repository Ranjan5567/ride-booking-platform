#!/bin/bash

# Deployment script for Ride Booking Platform
# This script helps automate the deployment process

set -e

echo "🚀 Starting Ride Booking Platform Deployment"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"
command -v terraform >/dev/null 2>&1 || { echo "Terraform not found. Please install Terraform."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found. Please install kubectl."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI not found. Please install AWS CLI."; exit 1; }
command -v az >/dev/null 2>&1 || { echo "Azure CLI not found. Please install Azure CLI."; exit 1; }

echo -e "${GREEN}✓ Prerequisites check passed${NC}"

# Deploy AWS Infrastructure
echo -e "${BLUE}Deploying AWS infrastructure...${NC}"
cd infra/aws
if [ ! -f terraform.tfvars ]; then
    echo "Please create terraform.tfvars file from terraform.tfvars.example"
    exit 1
fi

terraform init
terraform plan
read -p "Apply AWS infrastructure? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve
    echo -e "${GREEN}✓ AWS infrastructure deployed${NC}"
else
    echo "Skipping AWS infrastructure deployment"
fi

# Deploy Azure Infrastructure
echo -e "${BLUE}Deploying Azure infrastructure...${NC}"
cd ../azure
if [ ! -f terraform.tfvars ]; then
    echo "Please create terraform.tfvars file from terraform.tfvars.example"
    exit 1
fi

terraform init
terraform plan
read -p "Apply Azure infrastructure? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve
    echo -e "${GREEN}✓ Azure infrastructure deployed${NC}"
else
    echo "Skipping Azure infrastructure deployment"
fi

# Configure Kubernetes
echo -e "${BLUE}Configuring Kubernetes...${NC}"
cd ../..
EKS_CLUSTER_NAME=$(terraform -chdir=infra/aws output -raw eks_cluster_id 2>/dev/null || echo "ride-booking-eks")
AWS_REGION=$(terraform -chdir=infra/aws output -raw aws_region 2>/dev/null || echo "us-east-1")

aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
echo -e "${GREEN}✓ Kubernetes configured${NC}"

# Create secrets
echo -e "${BLUE}Creating Kubernetes secrets...${NC}"
echo "Please provide the following information:"
read -p "RDS Endpoint: " RDS_ENDPOINT
read -p "Database Password: " -s DB_PASSWORD
echo
read -p "Event Hub Connection String: " -s EVENTHUB_CS
echo

kubectl create secret generic db-credentials \
    --from-literal=host=$RDS_ENDPOINT \
    --from-literal=name=ridebooking \
    --from-literal=user=admin \
    --from-literal=password=$DB_PASSWORD \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic azure-credentials \
    --from-literal=eventhub_connection_string=$EVENTHUB_CS \
    --dry-run=client -o yaml | kubectl apply -f -

read -p "API Gateway URL: " API_URL
kubectl create configmap app-config \
    --from-literal=lambda_api_url=$API_URL \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Secrets created${NC}"

# Build and push Docker images
echo -e "${BLUE}Building Docker images...${NC}"
read -p "Docker registry URL (e.g., your-registry.com): " REGISTRY

SERVICES=("user-service" "driver-service" "ride-service" "payment-service")

for service in "${SERVICES[@]}"; do
    echo "Building $service..."
    cd backend/$service
    docker build -t $service:latest .
    docker tag $service:latest $REGISTRY/$service:latest
    docker push $REGISTRY/$service:latest
    cd ../..
done

echo -e "${GREEN}✓ Docker images built and pushed${NC}"

# Deploy ArgoCD
echo -e "${BLUE}Deploying ArgoCD...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo -e "${GREEN}✓ ArgoCD deployed${NC}"

# Get ArgoCD admin password
echo -e "${BLUE}ArgoCD Admin Password:${NC}"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo "Next steps:"
echo "1. Update gitops/argocd-apps.yaml with your Git repository URL"
echo "2. Apply ArgoCD applications: kubectl apply -f gitops/argocd-apps.yaml"
echo "3. Access ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "4. Deploy monitoring stack"
echo "5. Deploy frontend"

