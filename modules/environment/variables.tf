variable "environment" {
  type        = string
  description = "name of the environment, e.g dev or prod"
}

variable "location" {
  type    = string
  description = "Azure region to deploy resources in"
  default = "ukwest"
}

variable "vm_size" {
  type    = string
  description = "Size of the virtual machine to create"
  default = "Standard_D2als_v7"
}

variable "vnet_cidr" {
  type = string
  description = "address range for the virtual network, e.g. 10.0.0.0/16"
}

variable "web_subnet_cidr" {
  type = string
  description = "address range for the web subnet, e.g. 10.0.1.0/24"
}

variable "db_subnet_cidr" {
  type = string
  description = "address range for the database subnet, e.g. 10.0.2.0/24"
}

variable "resource_group_name" {
  type        = string
  default     = "rg-terraform-learn"
  description = "Name of the resource group"
}

variable "sql_admin_password" {
  type        = string
  sensitive = true
  description = "The password for the SQL Server administrator"
}

variable "sql_location" {
  type        = string
  description = "Region for SQL - trials can't provision SQL in ukwest"
  default     = "uksouth"
}