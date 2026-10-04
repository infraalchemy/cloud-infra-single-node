output "resource_group_name" {
  description = "Name of the ARO resource group"
  value       = azurerm_resource_group.aro.name
}

output "resource_group_location" {
  description = "Location of the ARO resource group"
  value       = azurerm_resource_group.aro.location
}