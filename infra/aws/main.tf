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

# VPC
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  project_name         = var.project_name
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "${var.project_name}-eks"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  public_subnets  = module.vpc.public_subnet_ids
  
  depends_on = [module.vpc]
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"
  
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  depends_on = [module.vpc]
}

# Lambda Function
module "lambda" {
  source = "./modules/lambda"
  
  function_name = "${var.project_name}-notification-lambda"
  handler       = "function.lambda_handler"
  runtime       = "python3.11"
}

# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"
  
  lambda_function_arn = module.lambda.function_arn
  lambda_function_name = module.lambda.function_name
}

# S3 Bucket
module "s3" {
  source = "./modules/s3"
  
  bucket_name = "${var.project_name}-assets-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

