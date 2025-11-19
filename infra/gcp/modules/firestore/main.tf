# Firestore Database for Analytics Results
resource "google_firestore_database" "analytics" {
  project          = var.project_id
  name             = var.database_id
  location_id      = var.location_id
  type             = "FIRESTORE_NATIVE"
  concurrency_mode = "OPTIMISTIC"
}

