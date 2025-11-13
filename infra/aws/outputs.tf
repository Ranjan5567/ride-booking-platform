output "eks_cluster_id" {
  description = "EKS Cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster Endpoint"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig" {
  description = "Kubeconfig for EKS cluster"
  value       = module.eks.kubeconfig
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS Database Endpoint"
  value       = module.rds.db_endpoint
}

output "api_gateway_url" {
  description = "API Gateway URL for Lambda"
  value       = "${module.api_gateway.api_url}/notify"
}

output "lambda_function_name" {
  description = "Lambda Function Name"
  value       = module.lambda.function_name
}

output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = module.s3.bucket_name
}
