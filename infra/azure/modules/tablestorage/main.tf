# Azure Table Storage - NoSQL alternative to Cosmos DB
# Student-friendly, cost-effective NoSQL storage

resource "azurerm_storage_account" "nosql" {
  name                     = "${replace(var.project_name, "-", "")}nosql"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally redundant storage
  account_kind             = "StorageV2"

  tags = {
    Environment = var.environment
    Purpose     = "NoSQL-Analytics"
  }
}

# Table for ride analytics results
resource "azurerm_storage_table" "ride_analytics" {
  name                 = "rideanalytics"
  storage_account_name = azurerm_storage_account.nosql.name
}

