output "endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "primary_key" {
  description = "Cosmos DB primary key"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "connection_string" {
  description = "Cosmos DB connection string"
  value       = azurerm_cosmosdb_account.main.primary_sql_connection_string
  sensitive   = true
}

output "database_name" {
  description = "Cosmos DB database name"
  value       = azurerm_cosmosdb_sql_database.analytics.name
}

output "container_name" {
  description = "Cosmos DB container name"
  value       = azurerm_cosmosdb_sql_container.ride_analytics.name
}

output "account_name" {
  description = "Cosmos DB account name"
  value       = azurerm_cosmosdb_account.main.name
}

