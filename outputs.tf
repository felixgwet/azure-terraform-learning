output "resource_group_id" {
  value       = azurerm_resource_group.main.id
  description = "The full Azure ID of the resource group"
}

output "resource_group_location" {
  value       = azurerm_resource_group.main.location
  description = "Where the resource group lives"
}