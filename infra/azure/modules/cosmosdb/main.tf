resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.project_name}-cosmosdb"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }
}

resource "azurerm_cosmosdb_mongo_database" "analytics" {
  name                = "analytics"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_mongo_collection" "ride_analytics" {
  name                = "ride_analytics"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_mongo_database.analytics.name

  default_ttl_seconds = 86400
  shard_key           = "city"
}

output "endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "primary_key" {
  value     = azurerm_cosmosdb_account.main.primary_key
  sensitive = true
}

output "database_name" {
  value = azurerm_cosmosdb_mongo_database.analytics.name
}

output "collection_name" {
  value = azurerm_cosmosdb_mongo_collection.ride_analytics.name
}

