# Dataproc Module - Managed Flink cluster for stream processing (requirement: stream processing)
# Consumes ride events from Pub/Sub, aggregates by city in 60-second windows, writes to Firestore

# Dataproc Cluster with Flink - runs real-time analytics on ride events
resource "google_dataproc_cluster" "flink_cluster" {
  name     = var.cluster_name
  project  = var.project_id
  region   = var.region

  cluster_config {
    # Let Dataproc use default buckets to avoid permission issues
    # staging_bucket = google_storage_bucket.dataproc_staging.name

    # Master node configuration
    master_config {
      num_instances = 1
      machine_type  = var.machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    # Worker nodes configuration
    worker_config {
      num_instances = var.num_workers
      machine_type  = var.machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    # Software configuration - enables Flink for stream processing
    # Flink is the stream processing engine that aggregates ride events
    software_config {
      image_version       = "2.2-debian12"
      optional_components = ["FLINK"]  # Built-in Flink component
      override_properties = {
        "dataproc:dataproc.allow.zero.workers" = "false"
      }
    }

    # GCE cluster configuration
    gce_cluster_config {
      zone         = var.zone
      network      = "default"
      subnetwork   = null
      tags         = ["dataproc", "flink"]
      service_account = null
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      # Enable external IPs for internet access (required for pip installs)
      internal_ip_only = false
    }

    # Initialization actions to install Python packages
    # Note: Temporarily disabled - packages will be installed manually after cluster creation
    # This avoids timeout issues during cluster creation
    # initialization_action {
    #   script      = "gs://${google_storage_bucket.dataproc_staging.name}/init-scripts/init_install_packages.sh"
    #   timeout_sec = 900
    # }
  }

  labels = {
    environment = "dev"
    purpose     = "flink-stream-processing"
    project     = var.project_name
  }
}

# Random ID for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Storage bucket for Dataproc - stores Flink job artifacts and staging files
# Dataproc uses this for job submission and temporary data
resource "google_storage_bucket" "dataproc_staging" {
  name          = "${var.project_id}-dataproc-staging-${random_id.bucket_suffix.hex}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    environment = "dev"
    purpose     = "dataproc-staging"
  }
}

# Grant compute service account access to staging bucket
data "google_project" "project" {
  project_id = var.project_id
}

locals {
  compute_sa = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "compute_sa_staging_access" {
  bucket = google_storage_bucket.dataproc_staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.compute_sa}"
}

# Grant compute service account storage admin on project level for temp buckets
resource "google_project_iam_member" "compute_sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.compute_sa}"
}

# Note: Initialization script should be uploaded manually to GCS
# The script is already at: gs://${google_storage_bucket.dataproc_staging.name}/init-scripts/init_install_packages.sh
# We upload it manually because Terraform path resolution from module is complex on Windows

