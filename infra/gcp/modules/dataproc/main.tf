# Dataproc Cluster for Flink
resource "google_dataproc_cluster" "flink_cluster" {
  name     = var.cluster_name
  project  = var.project_id
  region   = var.region

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc_staging.name

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

    # Software configuration with built-in Flink component
    software_config {
      image_version       = "2.2-debian12"
      optional_components = ["FLINK"]
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
    }
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

# Storage bucket for Dataproc staging
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

# Note: Flink is now installed via Dataproc's built-in optional_components
# No manual initialization script needed

