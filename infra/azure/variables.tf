variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ride-booking"
}

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

