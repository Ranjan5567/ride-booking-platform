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

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "dataproc.googleapis.com",
    "firestore.googleapis.com",
    "compute.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com"
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# Pub/Sub topics + IAM for ride events
module "pubsub" {
  source = "./modules/pubsub"

  project_id   = var.gcp_project_id
  project_name = var.project_name
  region       = var.gcp_region

  depends_on = [google_project_service.required_apis]
}

# Dataproc Cluster for Flink
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

# Firestore Database for Analytics Results
module "firestore" {
  source = "./modules/firestore"

  project_id   = var.gcp_project_id
  database_id  = "${var.project_name}-analytics"
  location_id  = var.firestore_location
  project_name = var.project_name

  depends_on = [google_project_service.required_apis]
}

