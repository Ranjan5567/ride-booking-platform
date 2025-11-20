data "google_project" "current" {
  project_id = var.project_id
}

locals {
  compute_default_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_pubsub_topic" "rides" {
  name = "${var.project_name}-rides"

  labels = {
    environment = "dev"
    purpose     = "ride-events"
  }

  message_retention_duration = "604800s" # 7 days
}

resource "google_pubsub_topic" "ride_results" {
  name = "${var.project_name}-ride-results"

  labels = {
    environment = "dev"
    purpose     = "ride-analytics"
  }

  message_retention_duration = "604800s"
}

resource "google_pubsub_subscription" "rides_flink" {
  name  = "${var.project_name}-rides-flink"
  topic = google_pubsub_topic.rides.name

  ack_deadline_seconds = 30
  retain_acked_messages = false
  message_retention_duration = "86400s"
}

# Service account used by AWS ride-service to publish into Pub/Sub
resource "google_service_account" "publisher" {
  account_id   = "${var.project_name}-pubsub-publisher"
  display_name = "Ride Service Pub/Sub Publisher"
}

resource "google_service_account_key" "publisher_key" {
  service_account_id = google_service_account.publisher.name
  keepers = {
    # Force recreation when SA is re-created
    service_account = google_service_account.publisher.name
  }
}

# Allow ride-service service account to publish to rides topic
resource "google_pubsub_topic_iam_member" "rides_publisher_binding" {
  topic  = google_pubsub_topic.rides.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.publisher.email}"
}

# Allow Dataproc (default compute SA) to consume rides subscription
resource "google_pubsub_subscription_iam_member" "flink_subscription_binding" {
  subscription = google_pubsub_subscription.rides_flink.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${locals.compute_default_sa}"
}

# Allow Dataproc (default compute SA) to publish aggregated events
resource "google_pubsub_topic_iam_member" "flink_results_publisher" {
  topic  = google_pubsub_topic.ride_results.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${locals.compute_default_sa}"
}

# Allow Dataproc default SA to write analytics to Firestore
resource "google_project_iam_member" "flink_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${locals.compute_default_sa}"
}

