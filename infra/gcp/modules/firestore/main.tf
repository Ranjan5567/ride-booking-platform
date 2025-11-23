# Firestore Module - NoSQL database for analytics results (requirement: cloud storage products - managed NoSQL)
# Stores aggregated ride counts by city - written by Dataproc Flink, read by frontend analytics dashboard
# This enables cross-cloud data access: AWS service (Ride Service) reads from GCP database

# Firestore Database - stores real-time analytics results from Flink stream processing
resource "google_firestore_database" "analytics" {
  project          = var.project_id
  name             = var.database_id
  location_id      = var.location_id
  type             = "FIRESTORE_NATIVE"
  concurrency_mode = "OPTIMISTIC"
}

