resource "google_dataproc_cluster" "flink" {
  name   = var.cluster_name
  region = var.region

  cluster_config {
    staging_bucket = var.staging_bucket

    # Enable Flink component
    software_config {
      image_version = "2.1-debian11"
      optional_components = ["FLINK"]
      
      properties = {
        "flink:taskmanager.numberOfTaskSlots" = "2"
        "flink:parallelism.default"            = "2"
      }
    }

    # Master node configuration
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    # Worker nodes configuration
    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }

    # Network configuration
    gce_cluster_config {
      network    = var.network
      subnetwork = var.subnetwork
      tags       = ["dataproc-cluster"]

      # Enable internal IP only for security (can be changed if needed)
      internal_ip_only = false
    }

    # Initialization script to configure Kafka credentials
    initialization_action {
      script      = google_storage_bucket_object.init_script.self_link
      timeout_sec = 500
    }
  }

  labels = {
    environment = "dev"
    purpose     = "flink-streaming"
  }
}

# Upload initialization script to configure Kafka
resource "google_storage_bucket_object" "init_script" {
  name   = "scripts/init-kafka-config.sh"
  bucket = var.staging_bucket
  content = templatefile("${path.module}/scripts/init-kafka-config.sh.tpl", {
    kafka_bootstrap  = var.kafka_bootstrap
    kafka_api_key    = var.kafka_api_key
    kafka_api_secret = var.kafka_api_secret
  })
}

# Get cluster details
data "google_dataproc_cluster" "flink" {
  name   = google_dataproc_cluster.flink.name
  region = var.region

  depends_on = [google_dataproc_cluster.flink]
}

output "cluster_name" {
  value = google_dataproc_cluster.flink.name
}

output "master_ip" {
  value = data.google_dataproc_cluster.flink.cluster_config[0].master_config[0].instance_names[0]
}

output "web_interfaces" {
  value = {
    flink_ui       = "http://${data.google_dataproc_cluster.flink.cluster_config[0].master_config[0].instance_names[0]}:8088"
    resource_manager = "http://${data.google_dataproc_cluster.flink.cluster_config[0].master_config[0].instance_names[0]}:8088"
  }
}

