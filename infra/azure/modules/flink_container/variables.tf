variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "project_name" {
  description = "Project name for naming resources"
  type        = string
}

variable "eventhub_connection_string" {
  description = "Event Hub connection string for Flink"
  type        = string
  sensitive   = true
}



