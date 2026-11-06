output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
  description = "Public IP address of the virtual machine - use this to SSH into the VM"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
  description = "Name of the resource group this environment is deployed in"
}
