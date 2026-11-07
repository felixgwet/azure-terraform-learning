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
variable "allowed_ssh_ip" {
  type        = string
  description = "The IP address allowed to SSH into the VM"
}
variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for VM admin login"
}
