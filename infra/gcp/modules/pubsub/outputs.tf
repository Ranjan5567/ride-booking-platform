output "rides_topic" {
  description = "Ride events Pub/Sub topic"
  value       = google_pubsub_topic.rides.name
}

output "ride_results_topic" {
  description = "Aggregated results Pub/Sub topic"
  value       = google_pubsub_topic.ride_results.name
}

output "rides_subscription" {
  description = "Subscription Flink uses to consume ride events"
  value       = google_pubsub_subscription.rides_flink.name
}

output "publisher_service_account_email" {
  description = "Service account email ride service uses to publish events"
  value       = google_service_account.publisher.email
}

output "publisher_service_account_key" {
  description = "Base64 encoded service account key JSON for ride service"
  value       = google_service_account_key.publisher_key.private_key
  sensitive   = true
}

