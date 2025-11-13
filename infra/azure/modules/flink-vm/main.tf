# Flink on Azure Container Instance
# Student-friendly alternative to HDInsight for stream processing

resource "azurerm_container_group" "flink" {
  name                = "${var.project_name}-flink"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  restart_policy      = "Always"

  # Flink JobManager Container
  container {
    name   = "flink-jobmanager"
    image  = "flink:1.18"
    cpu    = "1"
    memory = "2"

    ports {
      port     = 8081
      protocol = "TCP"
    }

    environment_variables = {
      FLINK_PROPERTIES = "jobmanager.rpc.address: localhost"
    }

    commands = ["jobmanager"]
  }

  # Flink TaskManager Container
  container {
    name   = "flink-taskmanager"
    image  = "flink:1.18"
    cpu    = "1"
    memory = "2"

    environment_variables = {
      FLINK_PROPERTIES = "jobmanager.rpc.address: localhost\ntaskmanager.numberOfTaskSlots: 2"
    }

    commands = ["taskmanager"]
  }

  ip_address_type = "Public"
  dns_name_label  = "${var.project_name}-flink"

  tags = {
    Environment = var.environment
    Purpose     = "Stream-Processing"
  }
}

