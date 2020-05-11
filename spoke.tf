# create project resource group for databricks users
resource "azurerm_resource_group" "databricks_rg" {
  name     = "rg_${var.team_name}_databricks"
  location = var.location
}

# add a private endpoint and private dns zone for accessing shared ADLS account using privatelink
resource "azurerm_private_dns_zone" "databricks_dns" {
  name = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

data "azurerm_private_endpoint_connection" "shared_datalake_connection" {
  name = azurerm_private_endpoint.storage_endpoint.name
  resource_group_name = azurerm_private_endpoint.storage_endpoint.resource_group_name
}

resource "azurerm_private_dns_a_record" "shared_datalake_dns" {
  name = azurerm_storage_account.shared_datalake.name
  resource_group_name = azurerm_resource_group.databricks_rg.name
  zone_name = azurerm_private_dns_zone.databricks_dns.name
  ttl = 300
  records = [data.azurerm_private_endpoint_connection.shared_datalake_connection.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name = "databricks_storage_endpoint_link"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.databricks_dns.name
  virtual_network_id = azurerm_virtual_network.databricks_vnet.id
}

# create a blank network security group for the databricks VNET
resource "azurerm_network_security_group" "databricks_nsg" {
  name = "nsg_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  # security rules will be added by Databricks during deployment
}

# databricks VNET with three subnets: public, private and a third reserved for private endpoints
resource "azurerm_virtual_network" "databricks_vnet" {
  name                = "vnet_${var.team_name}_databricks"
  address_space       = [var.workspace_vnet_cidr]
  location            = azurerm_resource_group.databricks_rg.location
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

resource "azurerm_subnet" "databricks_private_subnet" {
  name                 = "sn_prv_${var.team_name}_databricks"
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
  name = "sn_pub_${var.team_name}_databricks"
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
  name = "sn_prvlnk_${var.team_name}_databricks"
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
  name = "rt_fw_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  route {
    name           = "to-firewall"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
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

# create the workspace itself into the VNET created above
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

# extract the storage account name in the databricks managed resource group
data "azurerm_resources" "all_storage_accounts" {
  type = "Microsoft.Storage/storageAccounts"
}

locals {
  databricks_managed_rg_name = "${azurerm_resource_group.databricks_rg.name}_managed"
  databricks_managed_storage_account = [
  for account in data.azurerm_resources.all_storage_accounts.resources:
  "${account.name}.blob.core.windows.net"
  if length(regexall(local.databricks_managed_rg_name, account.id)) > 0
  ]
}

# add firewall rule for DBFS access
resource "azurerm_firewall_application_rule_collection" "fw_app_rules_dbfs" {
  action = "Allow"
  name = "databricks-control-plane-services"
  azure_firewall_name = azurerm_firewall.hub_fw.name
  priority = 200
  resource_group_name = azurerm_resource_group.hub_rg.name
  rule {
    name = "databricks-dbfs-${azurerm_resource_group.databricks_rg.name}"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    protocol {
      type = "Https"
      port = 443
    }
    target_fqdns = local.databricks_managed_storage_account
  }
}

# peer with the hub VNET
resource "azurerm_virtual_network_peering" "hub_databricks_peering" {
  name = "vnet_peering_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.databricks_vnet.id
}

resource "azurerm_virtual_network_peering" "databricks_hub_peering" {
  name = "vnet_peering_hub"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  virtual_network_name = azurerm_virtual_network.databricks_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id
}