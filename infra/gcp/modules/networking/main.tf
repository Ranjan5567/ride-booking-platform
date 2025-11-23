# Networking Module - provides internet access for Dataproc VMs
# Cloud NAT allows Dataproc to download packages, access Pub/Sub, etc.

# Cloud Router - required for Cloud NAT
resource "google_compute_router" "nat_router" {
  name    = "${var.project_name}-nat-router"
  region  = var.region
  network = "default"

  bgp {
    asn = 64514
  }
}

# Cloud NAT - provides outbound internet access for Dataproc VMs
# Allows Flink jobs to download Python packages, access external APIs, etc.
resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rule to allow all egress (public access)
resource "google_compute_firewall" "allow_all_egress" {
  name    = "${var.project_name}-allow-all-egress"
  network = "default"
  direction = "EGRESS"
  priority = 1000

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  target_tags = ["dataproc", "flink"]
}

# Firewall rule to allow all ingress (public access)
resource "google_compute_firewall" "allow_all_ingress" {
  name    = "${var.project_name}-allow-all-ingress"
  network = "default"
  direction = "INGRESS"
  priority = 1000

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["dataproc", "flink"]
}

