resource "google_firestore_database" "analytics" {
  project     = var.project_id
  name        = var.database_id
  location_id = var.location
  type        = "FIRESTORE_NATIVE"

  # Concurrency control
  concurrency_mode = "OPTIMISTIC"

  # App Engine integration (optional)
  app_engine_integration_mode = "DISABLED"
}

# Create a collection for ride analytics
# Note: Firestore collections are created automatically when documents are added
# This is just for documentation purposes

output "database_id" {
  value = google_firestore_database.analytics.name
}

output "location" {
  value = google_firestore_database.analytics.location_id
}

