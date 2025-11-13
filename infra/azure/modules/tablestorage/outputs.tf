output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.nosql.name
}

output "table_name" {
  description = "Table name for analytics"
  value       = azurerm_storage_table.ride_analytics.name
}

output "connection_string" {
  description = "Storage account connection string"
  value       = azurerm_storage_account.nosql.primary_connection_string
  sensitive   = true
}

output "primary_access_key" {
  description = "Storage account primary access key"
  value       = azurerm_storage_account.nosql.primary_access_key
  sensitive   = true
}

output "table_endpoint" {
  description = "Table storage endpoint"
  value       = azurerm_storage_account.nosql.primary_table_endpoint
}

