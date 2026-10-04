variable "resource_group_name" {
  description = "Name of the Azure resource group for ARO"
  type        = string
  default     = "rg-moodle-aro"
}

variable "location" {
  description = "Azure region for ARO"
  type        = string
  default     = "Canada Central"
}

variable "vnet_name" {
  description = "Name of the virtual network for ARO"
  type        = string
  default     = "vnet-moodle-aro"
}

variable "vnet_address_space" {
  description = "Address space for the ARO virtual network"
  type        = list(string)
  default     = ["10.0.0.0/22"]
}

variable "master_subnet_name" {
  description = "Name of the ARO control plane subnet"
  type        = string
  default     = "snet-aro-master"
}

variable "worker_subnet_name" {
  description = "Name of the ARO worker subnet"
  type        = string
  default     = "snet-aro-worker"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "moodlearoregistry"
}