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

# create 'hub' resources
resource "azurerm_resource_group" "hub_rg" {
  name     = "rg_hub"
  location = var.location
}

resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet_hub"
  address_space       = [var.hub_vnet_cidr]
  location            = azurerm_resource_group.databricks_rg.location
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

# start populating firewall rules
resource "azurerm_firewall_application_rule_collection" "fw_app_rules" {
  action = "Allow"
  name = "databricks-control-plane-services"
  azure_firewall_name = azurerm_firewall.hub_fw.name
  priority = 200
  resource_group_name = azurerm_resource_group.hub_rg.name
  rule {
    name = "databricks-spark-log-blob-storage"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    protocol {
      type = "Https"
      port = 443
    }
    target_fqdns = ["dblogprodukwest.blob.core.windows.net"]
  }
  rule {
    name = "databricks-artifact-blob-storage"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    protocol {
      type = "Https"
      port = 443
    }
    target_fqdns = ["dbartifactsproduksouth.blob.core.windows.net"]
  }
  rule {
    name = "databricks-dbfs"
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
  rule {
    name = "Public Repositories for Python and R Libraries"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    protocol {
      type = "Https"
      port = 443
    }
    target_fqdns = [
      "*pypi.org",
      "*pythonhosted.org",
      "cran.r-project.org"
    ]
  }
}

resource "azurerm_firewall_network_rule_collection" "fw_net_rules" {

  name = "databricks-control-plane-services"
  action = "Allow"
  azure_firewall_name = azurerm_firewall.hub_fw.name
  priority = 200
  resource_group_name = azurerm_resource_group.hub_rg.name
  rule {
    name = "databricks-webapp"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    destination_addresses = ["51.140.204.4/32"]
    destination_ports = [443]
    protocols = ["TCP"]
  }
  rule {
    name = "databricks-observability-eventhub"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    destination_addresses = ["51.140.210.34"]
    destination_ports = [9093]
    protocols = ["TCP"]
  }
  rule {
    name = "databricks-sql-metastore"
    source_addresses = [
      azurerm_subnet.databricks_private_subnet.address_prefix,
      azurerm_subnet.databricks_public_subnet.address_prefix
    ]
    destination_addresses = ["51.140.184.11"]
    destination_ports = [3306]
    protocols = ["TCP"]
  }
}

# create example resource group for shared resources e.g. corp data lake
resource "azurerm_resource_group" "shared_rg" {
  name     = "rg_shared"
  location = var.location
}

resource "azurerm_storage_account" "shared_datalake" {
  name = "shareddatalake"
  resource_group_name = azurerm_resource_group.shared_rg.name
  account_replication_type = "GRS"
  account_tier = "Standard"
  location = azurerm_resource_group.shared_rg.location
}

resource "azurerm_private_endpoint" "storage_endpoint" {
  name = "sa_datalake_endpoint"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  subnet_id = azurerm_subnet.databricks_privatelink_subnet.id
  private_service_connection {
    name = "sa_shared_datalake_psc"
    is_manual_connection = false
    private_connection_resource_id = azurerm_storage_account.shared_datalake.id
    subresource_names = ["dfs"]
  }
}

//resource "azurerm_eventhub" "shared_eventhub" {
//  name = "sa_shared_eventhub"
//  resource_group_name = azurerm_resource_group.shared_rg.name
//  message_retention = 1
//  namespace_name = "sa_shared_events"
//  partition_count = 1
//}


# create project resource group for databricks users
resource "azurerm_resource_group" "databricks_rg" {
  name     = "rg_${var.team_name}_databricks"
  location = var.location
}

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

resource "azurerm_network_security_group" "databricks_nsg" {
  name = "nsg_${var.team_name}_databricks"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  # security rules will be added by Databricks during deployment
}

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

resource "azurerm_subnet_network_security_group_association" "databricks_private_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_private_subnet.id
}

resource "azurerm_subnet_network_security_group_association" "databricks_public_subnet_nsg" {
  network_security_group_id = azurerm_network_security_group.databricks_nsg.id
  subnet_id = azurerm_subnet.databricks_public_subnet.id
}

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
