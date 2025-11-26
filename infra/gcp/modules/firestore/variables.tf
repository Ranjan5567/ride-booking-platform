variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "database_id" {
  description = "Firestore database ID"
  type        = string
}

variable "location_id" {
  description = "Firestore database location"
  type        = string
  default     = "us-central"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

