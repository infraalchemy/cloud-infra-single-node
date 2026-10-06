variable "resource_group_name" {
  description = "Name of the Azure resource group for ARO"
  type        = string
  default     = "rg-moodle-aro"
}

variable "location" {
  description = "Azure region for ARO"
  type        = string
  default     = "Central US"
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

variable "cluster_name" {
  description = "Name of the Azure Red Hat OpenShift cluster"
  type        = string
  default     = "moodle-aro-cluster"
}

variable "cluster_domain" {
  description = "Domain prefix used by the ARO cluster"
  type        = string
  default     = "moodle-aro"
}

variable "worker_vm_size" {
  description = "VM size for ARO worker nodes"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "worker_node_count" {
  description = "Number of ARO worker nodes"
  type        = number
  default     = 3
}

variable "master_vm_size" {
  description = "VM size for ARO control plane nodes"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "openshift_version" {
  description = "OpenShift version for the ARO cluster"
  type        = string
  default     = "4.20.15"
}

variable "aro_client_id" {
  description = "Client ID for the ARO service principal"
  type        = string
  sensitive   = true
}

variable "aro_client_secret" {
  description = "Client secret for the ARO service principal"
  type        = string
  sensitive   = true
}