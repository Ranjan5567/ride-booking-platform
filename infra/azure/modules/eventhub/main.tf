# Azure Event Hubs - Kafka-compatible managed service
# Student-friendly alternative to HDInsight Kafka

resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.project_name}-eventhub-ns"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"  # Standard tier supports Kafka protocol
  capacity            = 1

  tags = {
    Environment = var.environment
    Purpose     = "Kafka-compatible-messaging"
  }
}

# Topic for ride events
resource "azurerm_eventhub" "rides" {
  name                = "rides"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = 4
  message_retention   = 1  # 1 day retention
}

# Topic for processed ride analytics results
resource "azurerm_eventhub" "ride_results" {
  name                = "ride-results"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = 4
  message_retention   = 1
}

# Authorization rule for applications
resource "azurerm_eventhub_namespace_authorization_rule" "app_access" {
  name                = "app-access"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name

  listen = true
  send   = true
  manage = false
}
