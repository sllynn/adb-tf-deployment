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