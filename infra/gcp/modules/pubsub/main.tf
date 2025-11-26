# Pub/Sub Module - Event streaming infrastructure for cross-cloud communication
# AWS Ride Service publishes events here, GCP Dataproc Flink consumes them

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  compute_default_sa = "${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# Pub/Sub Topic - receives ride events from AWS Ride Service
# This enables cross-cloud event streaming: AWS → GCP
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

# Pub/Sub Subscription - consumed by Dataproc Flink for stream processing
resource "google_pubsub_subscription" "rides_flink" {
  name  = "${var.project_name}-rides-flink"
  topic = google_pubsub_topic.rides.name

  ack_deadline_seconds = 30
  retain_acked_messages = false
  message_retention_duration = "86400s"
}

# Service Account - used by AWS Ride Service to publish events to GCP Pub/Sub
# This enables cross-cloud authentication: AWS service authenticating to GCP
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

# IAM Bindings - grant permissions for cross-cloud and internal access

# Allow AWS Ride Service (via service account) to publish to rides topic
resource "google_pubsub_topic_iam_member" "rides_publisher_binding" {
  topic  = google_pubsub_topic.rides.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.publisher.email}"
}

# Allow Dataproc Flink to consume ride events from subscription
resource "google_pubsub_subscription_iam_member" "flink_subscription_binding" {
  subscription = google_pubsub_subscription.rides_flink.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.compute_default_sa}"
}

# Allow Dataproc Flink to publish aggregated results (optional - for downstream processing)
resource "google_pubsub_topic_iam_member" "flink_results_publisher" {
  topic  = google_pubsub_topic.ride_results.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${local.compute_default_sa}"
}

# Allow Dataproc Flink to write analytics results to Firestore
resource "google_project_iam_member" "flink_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${local.compute_default_sa}"
}

# PUBLIC ACCESS: Allow all authenticated users to publish to rides topic
resource "google_pubsub_topic_iam_member" "rides_public_publisher" {
  topic  = google_pubsub_topic.rides.name
  role   = "roles/pubsub.publisher"
  member = "allAuthenticatedUsers"
}

# PUBLIC ACCESS: Allow all authenticated users to publish to results topic
resource "google_pubsub_topic_iam_member" "results_public_publisher" {
  topic  = google_pubsub_topic.ride_results.name
  role   = "roles/pubsub.publisher"
  member = "allAuthenticatedUsers"
}

# PUBLIC ACCESS: Allow all authenticated users to subscribe to rides subscription
resource "google_pubsub_subscription_iam_member" "flink_public_subscriber" {
  subscription = google_pubsub_subscription.rides_flink.name
  role         = "roles/pubsub.subscriber"
  member       = "allAuthenticatedUsers"
}

