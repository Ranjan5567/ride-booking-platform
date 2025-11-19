output "cluster_name" {
  description = "HDInsight cluster name"
  value       = azurerm_hdinsight_hadoop_cluster.main.name
}

output "cluster_endpoint" {
  description = "HDInsight cluster HTTPS endpoint"
  value       = azurerm_hdinsight_hadoop_cluster.main.https_endpoint
}

output "cluster_ssh_endpoint" {
  description = "HDInsight cluster SSH endpoint"
  value       = azurerm_hdinsight_hadoop_cluster.main.ssh_endpoint
}

output "storage_account_name" {
  description = "Storage account name for HDInsight"
  value       = azurerm_storage_account.hdinsight.name
}

output "cluster_version" {
  description = "HDInsight cluster version"
  value       = azurerm_hdinsight_hadoop_cluster.main.cluster_version
}

