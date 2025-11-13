# GCP Infrastructure Outputs

output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.gcp_project_id
}

output "gcp_region" {
  description = "GCP Region"
  value       = var.gcp_region
}

# Dataproc Cluster Outputs
output "dataproc_cluster_name" {
  description = "Dataproc cluster name for Flink"
  value       = module.dataproc.cluster_name
}

output "dataproc_master_ip" {
  description = "Dataproc master node IP address"
  value       = module.dataproc.master_ip
}

output "dataproc_web_interfaces" {
  description = "Dataproc web interface URLs"
  value       = module.dataproc.web_interfaces
}

# Firestore Outputs
output "firestore_database_id" {
  description = "Firestore database ID"
  value       = module.firestore.database_id
}

output "firestore_location" {
  description = "Firestore location"
  value       = module.firestore.location
}

# Kafka Outputs (Confluent Cloud)
output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (Confluent Cloud)"
  value       = var.confluent_kafka_bootstrap
  sensitive   = true
}

# Storage Output
output "staging_bucket_name" {
  description = "Cloud Storage bucket for Dataproc staging"
  value       = google_storage_bucket.dataproc_staging.name
}

