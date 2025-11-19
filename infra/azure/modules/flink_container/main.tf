# Container Group for Flink (JobManager + TaskManager)
resource "azurerm_container_group" "flink" {
  name                = "${var.project_name}-flink"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "${var.project_name}-flink"

  # Flink JobManager Container
  container {
    name   = "flink-jobmanager"
    image  = "flink:1.17"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 8081
      protocol = "TCP"
    }

    ports {
      port     = 6123
      protocol = "TCP"
    }

    environment_variables = {
      JOB_MANAGER_RPC_ADDRESS = "localhost"
      FLINK_PROPERTIES = "jobmanager.rpc.address: localhost"
    }

    commands = ["jobmanager"]
  }

  # Flink TaskManager Container
  container {
    name   = "flink-taskmanager"
    image  = "flink:1.17"
    cpu    = "1"
    memory = "2"

    environment_variables = {
      JOB_MANAGER_RPC_ADDRESS = "localhost"
      FLINK_PROPERTIES = "jobmanager.rpc.address: localhost\ntaskmanager.numberOfTaskSlots: 2"
    }

    commands = ["taskmanager"]
  }

  tags = {
    Environment = "dev"
    Purpose     = "Flink-Stream-Processing"
  }
}

output "public_ip" {
  value = azurerm_container_group.flink.ip_address
}

output "flink_ui_url" {
  value = "http://${azurerm_container_group.flink.fqdn}:8081"
}



