resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.project_name}-cosmosdb"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableServerless"
  }

  tags = {
    Environment = "dev"
    Purpose     = "Analytics-NoSQL-Database"
  }
}

# Cosmos DB SQL Database for analytics
resource "azurerm_cosmosdb_sql_database" "analytics" {
  name                = "analytics"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# Cosmos DB SQL Container for ride analytics
resource "azurerm_cosmosdb_sql_container" "ride_analytics" {
  name                = "ride_analytics"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.analytics.name
  partition_key_path  = "/city"

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}

