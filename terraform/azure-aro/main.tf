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
  
  # Allow ARO instead of Azure to manage Private Link Service networking within this subnet
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "worker" {
  name                 = var.worker_subnet_name
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = ["10.0.2.0/23"]

  service_endpoints = ["Microsoft.ContainerRegistry"]
  
  # Allow ARO instead of Azure to manage Private Link Service networking within this subnet
  private_link_service_network_policies_enabled = false
}

resource "azurerm_container_registry" "aro" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aro.name
  location            = azurerm_resource_group.aro.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_redhat_openshift_cluster" "aro" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aro.location
  resource_group_name = azurerm_resource_group.aro.name

  cluster_profile {
    domain  = var.cluster_domain
    version = var.openshift_version
  }

  network_profile {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }

  main_profile {
    vm_size   = var.master_vm_size
    subnet_id = azurerm_subnet.master.id
  }

  worker_profile {
    vm_size      = var.worker_vm_size
    disk_size_gb = 128
    node_count   = var.worker_node_count
    subnet_id    = azurerm_subnet.worker.id
  }

  api_server_profile {
    visibility = "Public"
  }

  ingress_profile {
    visibility = "Public"
  }

  service_principal {
    client_id     = var.aro_client_id
    client_secret = var.aro_client_secret
  }
}