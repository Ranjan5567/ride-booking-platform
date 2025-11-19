# Azure Infrastructure Outputs

output "resource_group_name" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the Azure resource group"
  value       = azurerm_resource_group.main.location
}

# Event Hub Outputs
output "eventhub_namespace" {
  description = "Event Hub namespace name"
  value       = module.eventhub.namespace_name
}

output "eventhub_connection_string" {
  description = "Event Hub connection string (Kafka bootstrap)"
  value       = module.eventhub.connection_string
  sensitive   = true
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers (Event Hub endpoint)"
  value       = module.eventhub.kafka_endpoint
}

# Cosmos DB Outputs
output "cosmosdb_endpoint" {
  description = "Cosmos DB endpoint"
  value       = module.cosmosdb.endpoint
}

output "cosmosdb_connection_string" {
  description = "Cosmos DB connection string"
  value       = module.cosmosdb.connection_string
  sensitive   = true
}

output "cosmosdb_database_name" {
  description = "Cosmos DB database name"
  value       = module.cosmosdb.database_name
}

output "cosmosdb_container_name" {
  description = "Cosmos DB container name"
  value       = module.cosmosdb.container_name
}

# HDInsight Outputs
output "hdinsight_cluster_name" {
  description = "HDInsight cluster name"
  value       = module.hdinsight.cluster_name
}

output "hdinsight_cluster_endpoint" {
  description = "HDInsight cluster HTTPS endpoint"
  value       = module.hdinsight.cluster_endpoint
}

output "hdinsight_ssh_endpoint" {
  description = "HDInsight cluster SSH endpoint"
  value       = module.hdinsight.cluster_ssh_endpoint
}

output "flink_ui_url" {
  description = "Flink Web UI URL (via SSH tunnel to HDInsight)"
  value       = "ssh -L 8081:localhost:8081 ${var.hdinsight_ssh_username}@${module.hdinsight.cluster_ssh_endpoint}"
}

