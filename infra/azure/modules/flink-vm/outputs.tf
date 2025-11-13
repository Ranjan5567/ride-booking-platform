output "flink_ui_url" {
  description = "Flink Web UI URL"
  value       = "http://${azurerm_container_group.flink.fqdn}:8081"
}

output "flink_fqdn" {
  description = "Flink FQDN"
  value       = azurerm_container_group.flink.fqdn
}

output "flink_ip" {
  description = "Flink public IP"
  value       = azurerm_container_group.flink.ip_address
}

