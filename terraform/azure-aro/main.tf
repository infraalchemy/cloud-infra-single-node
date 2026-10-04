resource "azurerm_resource_group" "aro" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "aro" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name
}

resource "azurerm_subnet" "master" {
  name                 = var.master_subnet_name
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = ["10.0.0.0/23"]

  service_endpoints = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_subnet" "worker" {
  name                 = var.worker_subnet_name
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = ["10.0.2.0/23"]

  service_endpoints = ["Microsoft.ContainerRegistry"]
}

resource "azurerm_container_registry" "aro" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aro.name
  location            = azurerm_resource_group.aro.location
  sku                 = "Basic"
  admin_enabled       = false
}