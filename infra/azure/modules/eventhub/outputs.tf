output "namespace_name" {
  description = "Event Hub namespace name"
  value       = azurerm_eventhub_namespace.main.name
}

output "namespace_id" {
  description = "Event Hub namespace ID"
  value       = azurerm_eventhub_namespace.main.id
}

output "connection_string" {
  description = "Event Hub connection string (Kafka-compatible)"
  value       = azurerm_eventhub_namespace_authorization_rule.app_access.primary_connection_string
  sensitive   = true
}

output "kafka_bootstrap_servers" {
  description = "Kafka-compatible bootstrap servers endpoint"
  value       = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net:9093"
}

output "rides_topic" {
  description = "Rides event hub (Kafka topic)"
  value       = azurerm_eventhub.rides.name
}

output "results_topic" {
  description = "Results event hub (Kafka topic)"
  value       = azurerm_eventhub.ride_results.name
}

