variable "resource_group_name" {
  description = "Azure resource group for the ARO environment"
  type        = string
}

variable "location" {
  description = "Azure region for the ARO environment"
  type        = string
  default     = "Canada Central"
}