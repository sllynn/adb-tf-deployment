# create 'hub' resources
resource "azurerm_resource_group" "hub_rg" {
  name     = "rg_hub"
  location = var.hub_location
  tags = {
    Owner = var.hub_resource_owner
  }
}

resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet_hub"
  address_space       = [var.hub_vnet_cidr]
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
}

resource "azurerm_subnet" "hub_fw_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefix       = var.hub_fw_subnet_cidr
  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_public_ip" "hub_fw_publicip" {
  name                = "hub_fw_publicip"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "hub_fw" {
  name                = "hub_fw"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_fw_subnet.id
    public_ip_address_id = azurerm_public_ip.hub_fw_publicip.id
  }
}