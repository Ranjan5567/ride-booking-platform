terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet for Dataproc
resource "google_compute_subnetwork" "dataproc" {
  name          = "${var.project_name}-dataproc-subnet"
  ip_cidr_range = "10.2.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.main.id
}

# Firewall rules for Dataproc
resource "google_compute_firewall" "dataproc_internal" {
  name    = "${var.project_name}-dataproc-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.2.0.0/24"]
}

# Firewall rule for SSH
resource "google_compute_firewall" "ssh" {
  name    = "${var.project_name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["dataproc-cluster"]
}

# Cloud Storage bucket for Dataproc staging
resource "google_storage_bucket" "dataproc_staging" {
  name          = "${var.project_name}-dataproc-staging-${random_id.bucket_suffix.hex}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Dataproc cluster for Flink
module "dataproc" {
  source = "./modules/dataproc"

  project_id        = var.gcp_project_id
  region            = var.gcp_region
  cluster_name      = "${var.project_name}-flink"
  network           = google_compute_network.main.name
  subnetwork        = google_compute_subnetwork.dataproc.name
  staging_bucket    = google_storage_bucket.dataproc_staging.name
  kafka_bootstrap   = var.confluent_kafka_bootstrap
  kafka_api_key     = var.confluent_kafka_api_key
  kafka_api_secret  = var.confluent_kafka_api_secret
}

# Firestore database
module "firestore" {
  source = "./modules/firestore"

  project_id   = var.gcp_project_id
  location     = var.gcp_region
  database_id  = "${var.project_name}-analytics"
}

