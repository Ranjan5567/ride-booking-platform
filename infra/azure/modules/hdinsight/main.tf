# Storage Account for HDInsight
resource "azurerm_storage_account" "hdinsight" {
  name                     = "${replace(var.project_name, "-", "")}hdinsight${random_id.storage.hex}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_id" "storage" {
  byte_length = 4
}

resource "azurerm_storage_container" "hdinsight" {
  name                  = "hdinsight"
  storage_account_name  = azurerm_storage_account.hdinsight.name
  container_access_type = "private"
}

# HDInsight Flink Cluster
resource "azurerm_hdinsight_flink_cluster" "main" {
  name                = "${var.project_name}-flink"
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_version     = "4.0"
  tier                = "Standard"

  component_version {
    flink = "1.17.0"
  }

  gateway {
    username = "admin"
    password = "P@ssw0rd123!" # Change in production
  }

  storage_account {
    storage_container_id = azurerm_storage_container.hdinsight.id
    storage_account_key  = azurerm_storage_account.hdinsight.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size   = "Standard_D4s_v3"
      username  = "sshuser"
      password  = "P@ssw0rd123!" # Change in production
    }

    worker_node {
      target_instance_count = 2
      vm_size              = "Standard_D4s_v3"
      username             = "sshuser"
      password             = "P@ssw0rd123!" # Change in production
    }
  }

  tags = {
    Environment = "dev"
  }
}

output "cluster_name" {
  value = azurerm_hdinsight_flink_cluster.main.name
}

output "cluster_endpoint" {
  value = "https://${azurerm_hdinsight_flink_cluster.main.https_endpoint}"
}

