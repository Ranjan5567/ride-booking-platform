variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ride-booking"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# Confluent Cloud Kafka credentials
variable "confluent_kafka_bootstrap" {
  description = "Confluent Kafka bootstrap servers"
  type        = string
}

variable "confluent_kafka_api_key" {
  description = "Confluent Kafka API Key"
  type        = string
  sensitive   = true
}

variable "confluent_kafka_api_secret" {
  description = "Confluent Kafka API Secret"
  type        = string
  sensitive   = true
}

