variable "cluster_name" {
  description = "Name of the Dataproc cluster"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "machine_type" {
  description = "Machine type for cluster nodes"
  type        = string
  default     = "n1-standard-2"
}

variable "num_workers" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

# Kafka Configuration
variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (Confluent Cloud)"
  type        = string
  sensitive   = true
}

variable "kafka_api_key" {
  description = "Kafka API Key (Confluent Cloud)"
  type        = string
  sensitive   = true
}

variable "kafka_api_secret" {
  description = "Kafka API Secret (Confluent Cloud)"
  type        = string
  sensitive   = true
}

