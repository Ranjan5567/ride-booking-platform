# Azure Infrastructure Outputs

output "resource_group_name" {
  description = "Name of the Azure resource group"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the Azure resource group"
  value       = data.azurerm_resource_group.main.location
}

# Event Hub Outputs (Kafka-compatible)
output "eventhub_namespace" {
  description = "Event Hub namespace name"
  value       = module.eventhub.namespace_name
}

output "eventhub_connection_string" {
  description = "Event Hub connection string (Kafka-compatible)"
  value       = module.eventhub.connection_string
  sensitive   = true
}

output "kafka_bootstrap_servers" {
  description = "Kafka-compatible bootstrap servers (Event Hub)"
  value       = module.eventhub.kafka_bootstrap_servers
}

output "kafka_rides_topic" {
  description = "Rides topic name"
  value       = module.eventhub.rides_topic
}

output "kafka_results_topic" {
  description = "Results topic name"
  value       = module.eventhub.results_topic
}

# Table Storage Outputs (NoSQL)
output "tablestorage_account_name" {
  description = "Table Storage account name"
  value       = module.tablestorage.storage_account_name
}

output "tablestorage_table_name" {
  description = "Table Storage table name"
  value       = module.tablestorage.table_name
}

output "tablestorage_connection_string" {
  description = "Table Storage connection string"
  value       = module.tablestorage.connection_string
  sensitive   = true
}

output "tablestorage_endpoint" {
  description = "Table Storage endpoint"
  value       = module.tablestorage.table_endpoint
}

# Flink Container Instance Outputs
output "flink_ui_url" {
  description = "Flink Web UI URL"
  value       = module.flink.flink_ui_url
}

output "flink_fqdn" {
  description = "Flink FQDN"
  value       = module.flink.flink_fqdn
}

output "flink_ip" {
  description = "Flink public IP address"
  value       = module.flink.flink_ip
}
