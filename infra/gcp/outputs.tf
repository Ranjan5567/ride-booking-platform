output "dataproc_cluster_name" {
  description = "Dataproc cluster name"
  value       = module.dataproc.cluster_name
}

output "dataproc_cluster_endpoint" {
  description = "Dataproc cluster endpoint"
  value       = module.dataproc.cluster_endpoint
}

output "dataproc_master_uri" {
  description = "Dataproc master node URI"
  value       = module.dataproc.master_uri
}

output "firestore_database_id" {
  description = "Firestore database ID"
  value       = module.firestore.database_id
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = module.firestore.database_name
}

output "firestore_location" {
  description = "Firestore database location"
  value       = module.firestore.location
}

output "gcp_region" {
  description = "GCP Region"
  value       = var.gcp_region
}

output "gcp_zone" {
  description = "GCP Zone"
  value       = var.gcp_zone
}

# Note: Kafka bootstrap servers come from Confluent Cloud (external service)
# They are provided via terraform.tfvars, not as Terraform outputs

