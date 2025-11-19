# Storage Account for Table Storage
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.project_name, "-", "")}tablestorage"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Enable Table Storage
  enable_https_traffic_only = true

  tags = {
    Environment = "dev"
    Purpose     = "NoSQL-Analytics-Storage"
  }
}

# Table for ride analytics
resource "azurerm_storage_table" "ride_analytics" {
  name                 = "rideanalytics"
  storage_account_name = azurerm_storage_account.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "table_endpoint" {
  value = azurerm_storage_account.main.primary_table_endpoint
}

output "connection_string" {
  value     = azurerm_storage_account.main.primary_connection_string
  sensitive = true
}
