# AWS Infrastructure as Code (IaC) - Terraform configuration
# This file provisions all AWS resources: VPC, EKS, RDS, Lambda, API Gateway, S3
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module - Creates network infrastructure (VPC, subnets, NAT gateways, route tables)
# This provides network isolation and connectivity for all AWS resources
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  project_name         = var.project_name
}

# EKS Cluster Module - Managed Kubernetes cluster for microservices
# This is the core infrastructure requirement: managed K8s with HPA support
# All 4 backend microservices run as pods in this cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "${var.project_name}-eks"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  public_subnets  = module.vpc.public_subnet_ids
  
  depends_on = [module.vpc]
}

# RDS PostgreSQL Module - Managed SQL database (requirement: cloud storage products)
# Stores: users, drivers, rides, payments tables
# All microservices connect to this shared database
module "rds" {
  source = "./modules/rds"
  
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids  # Keep in private subnets but make publicly accessible
  
  depends_on = [module.vpc]
}

# Lambda Function Module - Serverless notification service (requirement: 6 microservices + serverless)
# This is one of the 6 services: Notification Service (Lambda)
# Event-driven, asynchronous notifications when rides are created
module "lambda" {
  source = "./modules/lambda"
  
  function_name = "${var.project_name}-notification-lambda"
  handler       = "function.lambda_handler"
  runtime       = "python3.11"
}

# API Gateway Module - HTTP endpoint for Lambda function
# Provides public URL that Ride Service calls to trigger notifications
module "api_gateway" {
  source = "./modules/api_gateway"
  
  lambda_function_arn = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
}

# S3 Bucket Module - Object storage (requirement: cloud storage products)
# Used for asset storage, Dataproc staging, etc.
module "s3" {
  source = "./modules/s3"
  
  bucket_name = "${var.project_name}-assets-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

