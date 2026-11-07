terraform {
  required_version = ">= 1.9.0"
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatelearn1990"
    container_name       = "tfstate"
    key                  = "lesson1.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "0e6b9288-bfc7-47f4-8186-226642c72051"
}


module "dev" {
  source = "./modules/environment"

  environment     = "dev"
  vnet_cidr       = "10.0.0.0/16"
  web_subnet_cidr = "10.0.1.0/24"
  db_subnet_cidr  = "10.0.2.0/24"
  vm_size         = "Standard_D2als_v7"
  sql_admin_password = var.sql_admin_password
  allowed_ssh_ip = var.allowed_ssh_ip
}

module "prod" {
  source = "./modules/environment"

  environment     = "prod"
  vnet_cidr       = "10.1.0.0/16"
  web_subnet_cidr = "10.1.1.0/24"
  db_subnet_cidr  = "10.1.2.0/24"
  vm_size         = "Standard_D2als_v7"
  sql_admin_password = var.sql_admin_password
  allowed_ssh_ip = var.allowed_ssh_ip
}
