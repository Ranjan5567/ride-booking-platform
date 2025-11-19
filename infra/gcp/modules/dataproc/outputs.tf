output "cluster_name" {
  description = "Dataproc cluster name"
  value       = google_dataproc_cluster.flink_cluster.name
}

output "cluster_endpoint" {
  description = "Dataproc cluster endpoint"
  value       = "https://${var.region}-dataproc.googleapis.com"
}

output "master_uri" {
  description = "Master node URI (use gcloud dataproc clusters describe to get actual endpoint)"
  value       = "https://${var.region}-dataproc.googleapis.com"
}

output "staging_bucket" {
  description = "Staging bucket name"
  value       = google_storage_bucket.dataproc_staging.name
}

