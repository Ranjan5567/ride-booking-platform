output "database_id" {
  description = "Firestore database ID"
  value       = google_firestore_database.analytics.name
}

output "database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.analytics.name
}

output "location" {
  description = "Firestore database location"
  value       = google_firestore_database.analytics.location_id
}

output "project_id" {
  description = "GCP Project ID"
  value       = google_firestore_database.analytics.project
}

