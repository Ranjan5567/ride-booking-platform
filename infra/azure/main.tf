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
  skip_provider_registration = true
}

# Use existing Resource Group (service principal has Contributor access)
data "azurerm_resource_group" "main" {
  name = "cloudProject"
}

# Event Hub - Kafka-compatible messaging (Student-friendly)
module "eventhub" {
  source = "./modules/eventhub"

  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  environment         = var.environment
}

# Table Storage - NoSQL for analytics (Student-friendly alternative to Cosmos DB)
module "tablestorage" {
  source = "./modules/tablestorage"

  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  environment         = var.environment
}

# Flink on Container Instance (Student-friendly alternative to HDInsight)
module "flink" {
  source = "./modules/flink-vm"

  project_name        = var.project_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  environment         = var.environment
}
