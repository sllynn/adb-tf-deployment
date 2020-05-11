variable "hub_location" {
  type = string
  default = "UK South"
  description = "Location for all hub resources."
}

variable "hub_resource_owner" {
  type = string
  default = "stuart@databricks.com"
  description = "Owner for hub resource group."
}

variable "shared_location" {
  type = string
  default = "UK South"
  description = "Location for all shared resources."
}

variable "shared_resource_owner" {
  type = string
  default = "stuart@databricks.com"
  description = "Owner for shared resource group."
}

variable "hub_vnet_cidr" {
  type = string
  default = "10.19.0.0/16"
  description = "CIDR range for the central hub vnet."
}

variable "hub_fw_subnet_cidr" {
  type = string
  default = "10.19.1.0/24"
  description = "CIDR range for firewall subnet within the central hub vnet."
}