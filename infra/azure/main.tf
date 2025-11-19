terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  # Use service principal credentials
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  
  skip_provider_registration = true
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.azure_location

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Virtual Network for HDInsight
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "azurerm_subnet" "hdinsight" {
  name                 = "hdinsight-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Event Hub Namespace (Kafka-compatible)
module "eventhub" {
  source = "./modules/eventhub"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
}

# Cosmos DB (NoSQL for Analytics)
module "cosmosdb" {
  source = "./modules/cosmosdb"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
}

# HDInsight Cluster with Flink
module "hdinsight" {
  source = "./modules/hdinsight"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  subnet_id           = azurerm_subnet.hdinsight.id
  virtual_network_id   = azurerm_virtual_network.main.id

  hdinsight_username     = var.hdinsight_username
  hdinsight_password     = var.hdinsight_password
  hdinsight_ssh_username = var.hdinsight_ssh_username
  hdinsight_ssh_password = var.hdinsight_ssh_password
}

