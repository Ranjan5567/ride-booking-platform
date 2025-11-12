variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "project_name" {
  type = string
}

variable "eventhub_namespace" {
  type = string
}

variable "eventhub_name" {
  type = string
}

variable "cosmosdb_endpoint" {
  type = string
}

variable "cosmosdb_key" {
  type      = string
  sensitive = true
}

