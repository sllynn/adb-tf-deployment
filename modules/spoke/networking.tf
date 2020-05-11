# create a blank network security group for the databricks VNET
resource "azurerm_network_security_group" "databricks_nsg" {
  name = "nsg_${var.spoke_name}"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  # security rules will be added by Databricks during deployment
}

# databricks VNET with three subnets: public, private and a third reserved for private endpoints
resource "azurerm_virtual_network" "databricks_vnet" {
  name                = "vnet_${var.spoke_name}"
  address_space       = [var.workspace_vnet_cidr]
  location            = azurerm_resource_group.databricks_rg.location
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

resource "azurerm_subnet" "databricks_private_subnet" {
  name                 = "sn_prv_${var.spoke_name}"
  resource_group_name  = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefix       = var.private_subnet_cidr

  delegation {
    name = "db_delegation"

    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_subnet" "databricks_public_subnet" {
  name = "sn_pub_${var.spoke_name}"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefix = var.public_subnet_cidr

  delegation {
    name = "db_delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

resource "azurerm_subnet" "databricks_privatelink_subnet" {
  name = "sn_prvlnk_${var.spoke_name}"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  address_prefix = var.privatelink_subnet_cidr
  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies = true
}

# associate our base NSG with the public and private subnets
resource "azurerm_subnet_network_security_group_association" "databricks_private_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_private_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_public_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_public_subnet.id
}

# route all traffic to the firewall, except communnication with control plane
resource "azurerm_route_table" "databricks_routing" {
  name = "rt_fw_${var.spoke_name}"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  route {
    name           = "to-firewall"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = var.azure_firewall_privateip #azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
  }
  route {
    name           = "to-control-plane"
    address_prefix = "51.140.203.27/32"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "databricks_routing_private" {
  route_table_id = azurerm_route_table.databricks_routing.id
  subnet_id = azurerm_subnet.databricks_private_subnet.id
}

resource "azurerm_subnet_route_table_association" "databricks_routing_public" {
  route_table_id = azurerm_route_table.databricks_routing.id
  subnet_id = azurerm_subnet.databricks_public_subnet.id
}

# peer with the hub VNET
resource "azurerm_virtual_network_peering" "hub_databricks_peering" {
  name = "vnet_peering_${var.spoke_name}"
  resource_group_name = var.hub_rg_name #azurerm_resource_group.hub_rg.name
  virtual_network_name = var.hub_vnet_name #azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.databricks_vnet.id
}

resource "azurerm_virtual_network_peering" "databricks_hub_peering" {
  name = "vnet_peering_hub"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  remote_virtual_network_id = var.hub_vnet_id #azurerm_virtual_network.hub_vnet.id
}