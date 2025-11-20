variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Name prefix used for Pub/Sub resources"
  type        = string
}

variable "region" {
  description = "GCP region (for message storage policy hints)"
  type        = string
}

