# extract the storage account name in the databricks managed resource group
data "azurerm_resources" "all_storage_accounts" {
  depends_on = [azurerm_databricks_workspace.databricks_workspace]
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

# start populating firewall rules
resource "azurerm_firewall_application_rule_collection" "fw_app_rules" {
  depends_on = [azurerm_databricks_workspace.databricks_workspace, local.databricks_managed_storage_account]
  action = "Allow"
  name = "databricks-control-plane-services-${var.spoke_name}"
  azure_firewall_name = var.azure_firewall_name #azurerm_firewall.hub_fw.name
  priority = var.azure_firewall_rules_priority
  resource_group_name = var.hub_rg_name #azurerm_resource_group.hub_rg.name
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
    name = "public-repos"
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
  name = "databricks-control-plane-services-${var.spoke_name}"
  depends_on = [azurerm_databricks_workspace.databricks_workspace, local.databricks_managed_storage_account]
  action = "Allow"
  azure_firewall_name = var.azure_firewall_name #azurerm_firewall.hub_fw.name
  priority = var.azure_firewall_rules_priority
  resource_group_name = var.hub_rg_name #azurerm_resource_group.hub_rg.name
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