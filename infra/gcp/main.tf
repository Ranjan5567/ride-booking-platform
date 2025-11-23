# GCP Infrastructure as Code (IaC) - Terraform configuration
# This file provisions all GCP resources: Dataproc (Flink), Pub/Sub, Firestore
# This is Provider B - handles analytics pipeline (requirement: multi-cloud)

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Enable required GCP APIs - must be enabled before creating resources
resource "google_project_service" "required_apis" {
  for_each = toset([
    "dataproc.googleapis.com",
    "firestore.googleapis.com",
    "compute.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# Networking Module - Cloud NAT and Firewall Rules for internet access
# Allows Dataproc VMs to download packages and access external services
module "networking" {
  source = "./modules/networking"

  project_id   = var.gcp_project_id
  project_name = var.project_name
  region       = var.gcp_region

  depends_on = [google_project_service.required_apis]
}

# Pub/Sub Module - Message queue for event streaming (requirement: stream processing)
# Receives ride events from AWS Ride Service, consumed by Dataproc Flink
module "pubsub" {
  source = "./modules/pubsub"

  project_id   = var.gcp_project_id
  project_name = var.project_name
  region       = var.gcp_region

  depends_on = [google_project_service.required_apis]
}

# Dataproc Cluster Module - Managed Flink cluster (requirement: stream processing with Flink)
# Runs real-time analytics on ride events, aggregates by city in 60-second windows
module "dataproc" {
  source = "./modules/dataproc"

  cluster_name    = "${var.project_name}-flink-cluster"
  project_id      = var.gcp_project_id
  region          = var.gcp_region
  zone            = var.gcp_zone
  machine_type    = var.dataproc_machine_type
  num_workers     = var.dataproc_num_workers
  project_name    = var.project_name

  depends_on = [google_project_service.required_apis]
}

# Firestore Module - NoSQL database for analytics results (requirement: cloud storage products - managed NoSQL)
# Stores aggregated ride counts by city, read by frontend for analytics dashboard
module "firestore" {
  source = "./modules/firestore"

  project_id   = var.gcp_project_id
  database_id  = "${var.project_name}-analytics"
  location_id  = var.firestore_location
  project_name = var.project_name

  depends_on = [google_project_service.required_apis]
}

