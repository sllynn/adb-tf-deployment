variable "credentials" {
  type = object({
    subscription_id = string
    client_id = string
    tenant_id = string
    client_secret = string
  })
}

variable "team_name" {
  type = string
  description = "The name of the team for whom resources are being deployed."
}

variable "location" {
  type = string
  default = "UK South"
  description = "Location for all resources."
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

variable "workspace_vnet_cidr" {
  type = string
  default = "10.179.0.0/16"
  description = "CIDR range for the Databricks data plane vnet."
}

variable "private_subnet_cidr" {
  type = string
  default = "10.179.1.0/24"
  description = "CIDR range for the private subnet."
}

variable "public_subnet_cidr" {
  type = string
  default = "10.179.2.0/24"
  description = "CIDR range for the public subnet."
}

variable "privatelink_subnet_cidr" {
  type = string
  default = "10.179.3.0/24"
  description = "CIDR range for the public subnet."
}