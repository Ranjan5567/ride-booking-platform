output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "eventhub_connection_string" {
  value     = module.eventhub.connection_string
  sensitive = true
}

output "cosmosdb_endpoint" {
  value = module.cosmosdb.endpoint
}

output "hdinsight_cluster_name" {
  value = module.hdinsight.cluster_name
}

