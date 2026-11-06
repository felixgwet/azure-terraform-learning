variable "location" {
  type        = string
  default     = "ukwest"
  description = "Which Azure region everything goes in"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-terraform-learn"
  description = "Name of the resource group"
}

variable "environment" {
  type        = string
  default     = "learning"
  description = "Environment tag value (learning, dev, prod...)"
}
variable "sql_admin_password" {
  type        = string
  sensitive = true
  description = "The password for the SQL Server administrator"
}