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

variable "vnet_cidr" {
  type = string
  default = "10.179.0.0/16"
  description = "CIDR range for the Databricks data plane vnet."
}

variable "private_subnet_cidr" {
  type = string
  default = "10.179.0.0/18"
  description = "CIDR range for the private subnet."
}

variable "public_subnet_cidr" {
  type = string
  default = "10.179.64.0/18"
  description = "CIDR range for the public subnet."
}

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.0.0"
  tenant_id       = var.credentials.tenant_id
  subscription_id = var.credentials.subscription_id
  client_id       = var.credentials.client_id
  client_secret   = var.credentials.client_secret
  features {}
}

resource "azurerm_resource_group" "databricks_rg" {
  name     = "rg_${var.team_name}_databricks"
  location = var.location
}

resource "azurerm_network_security_group" "databricks_nsg" {
  name = "nsg_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  # security rules will be added by Databricks during deployment
}

resource "azurerm_virtual_network" "databricks_vnet" {
  name                = "vnet_${var.team_name}_databricks"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.databricks_rg.location
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

resource "azurerm_subnet" "databricks_private_subnet" {
name                 = "sn_prv_${var.team_name}_databricks"
resource_group_name  = azurerm_resource_group.databricks_rg.name
virtual_network_name = azurerm_virtual_network.databricks_vnet.name
address_prefix       = "10.0.2.0/24"

delegation {
  name = "db_delegation"

  service_delegation {
    name    = "Microsoft.Databricks/workspaces"
  }
}
}

resource "azurerm_subnet" "databricks_public_subnet" {
  name = "sn_pub_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefix = var.public_subnet_cidr

  delegation {
    name = "db_delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "databricks_private_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_private_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_public_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_public_subnet.id
}

resource "azurerm_databricks_workspace" "databricks_workspace" {
  name = "databricks_workspace_${var.team_name}"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  sku = "premium"
  managed_resource_group_name = "${azurerm_resource_group.databricks_rg.name}_managed"
  custom_parameters {
    no_public_ip = false
    public_subnet_name = azurerm_subnet.databricks_public_subnet.name
    private_subnet_name = azurerm_subnet.databricks_private_subnet.name
    virtual_network_id = azurerm_virtual_network.databricks_vnet.id
  }
}
