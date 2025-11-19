variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for HDInsight cluster (optional)"
  type        = string
  default     = null
}

variable "virtual_network_id" {
  description = "Virtual Network ID for HDInsight cluster (required if subnet_id is set)"
  type        = string
  default     = null
}

variable "hdinsight_username" {
  description = "HDInsight gateway username"
  type        = string
  default     = "admin"
}

variable "hdinsight_password" {
  description = "HDInsight gateway password"
  type        = string
  default     = "P@ssw0rd123!"
  sensitive   = true
}

variable "hdinsight_ssh_username" {
  description = "HDInsight SSH username"
  type        = string
  default     = "sshuser"
}

variable "hdinsight_ssh_password" {
  description = "HDInsight SSH password"
  type        = string
  default     = "P@ssw0rd123!"
  sensitive   = true
}

