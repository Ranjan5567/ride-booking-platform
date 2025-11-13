# Cloud Credentials Configuration

## ✅ Configuration Complete

All cloud credentials have been configured successfully for the BITS Ride Booking Project.

---

## AWS Configuration (Mumbai Region - ap-south-1)

### Account Details
- **Account ID:** `943812325535`
- **User:** `cloudProject`
- **User ARN:** `arn:aws:iam::943812325535:user/cloudProject`
- **Region:** `ap-south-1` (Mumbai)

### ECR Registry URL
```
943812325535.dkr.ecr.ap-south-1.amazonaws.com
```

### Configured Services
- ✅ AWS Access Key ID: `AKIA5XP4ZGCPQE7B3FWT`
- ✅ AWS Secret Access Key: Configured
- ✅ Default Region: `ap-south-1`
- ✅ Default Output: `json`

### Verification
```bash
aws sts get-caller-identity
```

**Status:** ✅ Connected and Verified

---

## Azure Configuration (Central India Region)

### Account Details
- **Subscription:** Azure for Students
- **Subscription ID:** `d3af6d19-dac0-4987-b588-c85fed90b622`
- **Tenant ID:** `d7fd0f1f-3148-4594-868c-4b6925def9ff`
- **Service Principal ID:** `be95dd27-abe2-4a0e-b54a-7d5bbbce7ea6`
- **Region:** `centralindia` (Central India)

### Authentication Method
- Service Principal (for automation)
- Login Type: `servicePrincipal`

### Verification
```bash
az account show
```

**Status:** ✅ Connected and Verified

---

## Project Configuration

### Infrastructure Regions
| Service | Region | Purpose |
|---------|--------|---------|
| **AWS EKS** | ap-south-1 | Kubernetes cluster for microservices |
| **AWS RDS** | ap-south-1 | PostgreSQL database |
| **AWS Lambda** | ap-south-1 | Notification service |
| **AWS ECR** | ap-south-1 | Docker image registry |
| **AWS S3** | ap-south-1 | Object storage |
| **Azure Event Hub** | centralindia | Kafka-compatible message queue |
| **Azure HDInsight** | centralindia | Flink stream processing |
| **Azure Cosmos DB** | centralindia | NoSQL analytics database |

### Updated Files
All configuration files have been updated with correct credentials:
- ✅ `infra/aws/variables.tf` - Region: ap-south-1
- ✅ `infra/aws/terraform.tfvars.example` - Region: ap-south-1
- ✅ `infra/azure/variables.tf` - Region: centralindia
- ✅ `infra/azure/terraform.tfvars.example` - Region: centralindia
- ✅ `DEPLOYMENT.md` - ECR Account ID: 943812325535
- ✅ `README.md` - Updated regions
- ✅ `scripts/deploy.sh` - Updated regions

---

## Next Steps

### ⚠️ Important: Do NOT Proceed Yet!

As per your instructions, **only login is complete**. No infrastructure deployment commands have been executed.

### When Ready to Deploy:

1. **Create ECR Repositories:**
   ```bash
   aws ecr create-repository --repository-name user-service --region ap-south-1
   aws ecr create-repository --repository-name driver-service --region ap-south-1
   aws ecr create-repository --repository-name ride-service --region ap-south-1
   aws ecr create-repository --repository-name payment-service --region ap-south-1
   ```

2. **Deploy AWS Infrastructure:**
   ```bash
   cd infra/aws
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Azure Infrastructure:**
   ```bash
   cd infra/azure
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed
   terraform init
   terraform plan
   terraform apply
   ```

4. **Follow DEPLOYMENT.md for complete deployment process**

---

## Security Notes

⚠️ **Important Security Reminders:**
- AWS credentials are stored in `~/.aws/credentials`
- Azure credentials are cached by Azure CLI
- Never commit credentials to Git
- Rotate credentials regularly
- Use IAM roles and service principals for automation

---

## Verification Commands

### Check AWS Connection
```bash
aws sts get-caller-identity
aws s3 ls  # Test S3 access
aws eks list-clusters --region ap-south-1  # Test EKS access
```

### Check Azure Connection
```bash
az account show
az group list --output table  # Test resource access
az vm list --output table  # Test compute access
```

---

**Configuration Date:** November 13, 2024
**Status:** ✅ Both clouds connected and ready for deployment
**Action Required:** Awaiting deployment instructions

---

## Contact & Support

For deployment questions, refer to:
- `DEPLOYMENT.md` - Complete deployment guide
- `REDEPLOYMENT_GUIDE.md` - Redeployment instructions
- `docs/DEMO_SCRIPT.md` - Demo walkthrough


