variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"  # Mumbai, India
}

variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ride-booking"
}

variable "dataproc_machine_type" {
  description = "Machine type for Dataproc cluster nodes"
  type        = string
  default     = "n1-standard-2"
}

variable "dataproc_num_workers" {
  description = "Number of worker nodes in Dataproc cluster"
  type        = number
  default     = 2
}

variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "asia-south1"  # Mumbai, India
}
