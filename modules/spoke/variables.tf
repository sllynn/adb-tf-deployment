variable "spoke_name" {
  type = string
  description = "The name of the team for whom resources are being deployed."
}

variable "spoke_location" {
  type = string
  description = "Location for all spoke resources."
}

variable "spoke_resource_owner" {
  type = string
  description = "Owner for spoke resource group."
}

variable "shared_datalake_name" {
  type = string
  description = "Name of shared storage account"
}

variable "shared_datalake_id" {
  type = string
  description = "ID of shared storage account"
}

variable "workspace_vnet_cidr" {
  type = string
  description = "CIDR range for the Databricks data plane vnet."
}

variable "private_subnet_cidr" {
  type = string
  description = "CIDR range for the private subnet."
}

variable "public_subnet_cidr" {
  type = string
  description = "CIDR range for the public subnet."
}

variable "privatelink_subnet_cidr" {
  type = string
  description = "CIDR range for the public subnet."
}

variable "azure_firewall_name" {
  type = string
  description = "Name of Azure Firewall"
}

variable "azure_firewall_privateip" {
  type = string
  description = "Private IP address of Azure Firewall"
}

variable "hub_rg_name" {
  type = string
  description = "Name of hub resource group"
}

variable "hub_vnet_name" {
  type = string
  description = "Name of hub VNET for pairing"
}

variable "hub_vnet_id" {
  type = string
  description = "ID of hub VNET for pairing"
}

variable "azure_firewall_rules_priority" {
  type = number
  description = "Priority index for firewall rule set (must be unique for each spoke)"
}