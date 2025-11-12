resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.project_name}-eh-namespace"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  capacity            = 1

  tags = {
    Environment = "dev"
  }
}

resource "azurerm_eventhub" "rides" {
  name                = "rides"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "main" {
  name                = "send-listen-rule"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.rides.name
  resource_group_name = var.resource_group_name
  listen              = true
  send                = true
  manage              = false
}

output "namespace_name" {
  value = azurerm_eventhub_namespace.main.name
}

output "eventhub_name" {
  value = azurerm_eventhub.rides.name
}

output "connection_string" {
  value     = azurerm_eventhub_authorization_rule.main.primary_connection_string
  sensitive = true
}

output "namespace_fqdn" {
  value = azurerm_eventhub_namespace.main.default_primary_connection_string
}

