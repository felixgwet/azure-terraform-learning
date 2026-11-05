variable "environment" {
  type        = string
  description = "dev"
}

variable "location" {
  type    = string
  default = "ukwest"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2als_v7"
}

variable "vnet_cidr" {
  type = string
}

variable "web_subnet_cidr" {
  type = string
}

variable "db_subnet_cidr" {
  type = string
}