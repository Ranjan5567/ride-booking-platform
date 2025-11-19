# Event Hub Namespace (Kafka-compatible)
resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.project_name}-eventhub-ns"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"  # Basic doesn't support Kafka
  capacity            = 1

  tags = {
    Environment = "dev"
    Purpose     = "Kafka-Compatible-Messaging"
  }
}

# Event Hub (Topic) for rides
resource "azurerm_eventhub" "rides" {
  name                = "rides"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = 3
  message_retention   = 1  # days
}

# Event Hub (Topic) for ride results
resource "azurerm_eventhub" "ride_results" {
  name                = "ride-results"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = 3
  message_retention   = 1  # days
}

# Authorization Rule for accessing Event Hub
resource "azurerm_eventhub_namespace_authorization_rule" "main" {
  name                = "RootManageSharedAccessKey"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name

  listen = true
  send   = true
  manage = true
}

output "namespace_name" {
  value = azurerm_eventhub_namespace.main.name
}

output "connection_string" {
  value     = azurerm_eventhub_namespace_authorization_rule.main.primary_connection_string
  sensitive = true
}

output "kafka_endpoint" {
  value = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net:9093"
}
