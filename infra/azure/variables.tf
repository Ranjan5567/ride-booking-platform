variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_location" {
  description = "Azure Region"
  type        = string
  default     = "southeastasia"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ride-booking"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "cloudProject"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# HDInsight Variables
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

