terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Storage Account for HDInsight
resource "azurerm_storage_account" "hdinsight" {
  name                     = "rbhd${random_string.storage_suffix.result}"  # Shortened to fit 24 char limit
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = {
    Environment = "dev"
    Purpose     = "HDInsight-Storage"
  }
}

resource "azurerm_storage_container" "hdinsight" {
  name                  = "hdinsight"
  storage_account_name  = azurerm_storage_account.hdinsight.name
  container_access_type = "private"
}

# HDInsight Hadoop Cluster with Flink
resource "azurerm_hdinsight_hadoop_cluster" "main" {
  name                = "${var.project_name}-hdinsight"
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_version     = "4.0"  # Changed from 5.1 - 5.1 doesn't support Hadoop 3.1
  tier                = "Standard"

  component_version {
    hadoop = "3.1"
  }

  gateway {
    username = var.hdinsight_username
    password = var.hdinsight_password
  }

  storage_account {
    storage_container_id = azurerm_storage_container.hdinsight.id
    storage_account_key  = azurerm_storage_account.hdinsight.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size           = "Standard_D2_V2"  # Reduced from D3_V2 (4 cores) to D2_V2 (2 cores)
      username          = var.hdinsight_ssh_username
      password          = var.hdinsight_ssh_password
      subnet_id         = var.subnet_id
      virtual_network_id = var.virtual_network_id
    }

    worker_node {
      vm_size           = "Standard_D2_V2"  # Reduced from D3_V2 (4 cores) to D2_V2 (2 cores)
      username          = var.hdinsight_ssh_username
      password          = var.hdinsight_ssh_password
      target_instance_count = 1
      subnet_id         = var.subnet_id
      virtual_network_id = var.virtual_network_id
    }

    zookeeper_node {
      vm_size           = "Standard_A2_V2"  # 2 cores (minimum for zookeeper)
      username          = var.hdinsight_ssh_username
      password          = var.hdinsight_ssh_password
      subnet_id         = var.subnet_id
      virtual_network_id = var.virtual_network_id
    }
  }

  tags = {
    Environment = "dev"
    Purpose     = "Flink-Stream-Processing"
  }
}

# Note: Flink can be installed manually via SSH after cluster creation
# Using the following commands:
# wget https://archive.apache.org/dist/flink/flink-1.17.1/flink-1.17.1-bin-scala_2.12.tgz
# tar -xzf flink-1.17.1-bin-scala_2.12.tgz
# cd flink-1.17.1
# ./bin/start-cluster.sh

