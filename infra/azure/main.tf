terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.azure_location

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Event Hub Namespace
module "eventhub" {
  source = "./modules/eventhub"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
}

# Cosmos DB
module "cosmosdb" {
  source = "./modules/cosmosdb"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
}

# HDInsight Flink Cluster
module "hdinsight" {
  source = "./modules/hdinsight"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  eventhub_namespace  = module.eventhub.namespace_name
  eventhub_name       = module.eventhub.eventhub_name
  cosmosdb_endpoint   = module.cosmosdb.endpoint
  cosmosdb_key        = module.cosmosdb.primary_key
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "eventhub_namespace" {
  value = module.eventhub.namespace_name
}

output "eventhub_connection_string" {
  value     = module.eventhub.connection_string
  sensitive = true
}

output "cosmosdb_endpoint" {
  value = module.cosmosdb.endpoint
}

output "cosmosdb_database_name" {
  value = module.cosmosdb.database_name
}

output "hdinsight_cluster_name" {
  value = module.hdinsight.cluster_name
}

