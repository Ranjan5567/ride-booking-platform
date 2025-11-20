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

output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.gcp_project_id
}

# Pub/Sub resources
output "pubsub_rides_topic" {
  description = "Ride events Pub/Sub topic name"
  value       = module.pubsub.rides_topic
}

output "pubsub_rides_subscription" {
  description = "Subscription Flink uses to consume ride events"
  value       = module.pubsub.rides_subscription
}

output "pubsub_results_topic" {
  description = "Aggregated analytics Pub/Sub topic"
  value       = module.pubsub.ride_results_topic
}

output "pubsub_publisher_service_account_email" {
  description = "Service account email ride-service uses to publish to Pub/Sub"
  value       = module.pubsub.publisher_service_account_email
}

output "pubsub_publisher_service_account_key" {
  description = "Base64 encoded service account key JSON (pass to ride-service secret)"
  value       = module.pubsub.publisher_service_account_key
  sensitive   = true
}

