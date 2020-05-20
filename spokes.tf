locals {
  hub_rg_name = azurerm_resource_group.hub_rg.name
  hub_vnet_name = azurerm_virtual_network.hub_vnet.name
  hub_vnet_id = azurerm_virtual_network.hub_vnet.id
  azure_firewall_name = azurerm_firewall.hub_fw.name
  azure_firewall_privateip = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
  shared_datalake_id = azurerm_storage_account.shared_datalake.id
  shared_datalake_name = azurerm_storage_account.shared_datalake.name
}

module "adb_spoke_stuart" {
  source = "./modules/spoke"
  workspace_vnet_cidr = "10.179.0.0/16"
  private_subnet_cidr =  "10.179.1.0/24"
  public_subnet_cidr = "10.179.2.0/24"
  privatelink_subnet_cidr = "10.179.3.0/24"
  spoke_name = "adb_spoke_stuart"
  spoke_location = "UK South"
  spoke_resource_owner = "stuart@databricks.com"
  hub_rg_name = local.hub_rg_name
  hub_vnet_name = local.hub_vnet_name
  hub_vnet_id = local.hub_vnet_id
  azure_firewall_name = local.azure_firewall_name
  azure_firewall_privateip = local.azure_firewall_privateip
  azure_firewall_rules_priority = 200
  shared_datalake_id = local.shared_datalake_id
  shared_datalake_name = local.shared_datalake_name
}

//module "adb_spoke_acme" {
//  source = "./modules/spoke"
//  workspace_vnet_cidr = "10.178.0.0/16"
//  private_subnet_cidr =  "10.178.1.0/24"
//  public_subnet_cidr = "10.178.2.0/24"
//  privatelink_subnet_cidr = "10.178.3.0/24"
//  spoke_name = "adb_spoke_acme"
//  spoke_location = "UK South"
//  spoke_resource_owner = "stuart@databricks.com"
//  hub_rg_name = local.hub_rg_name
//  hub_vnet_name = local.hub_vnet_name
//  hub_vnet_id = local.hub_vnet_id
//  azure_firewall_name = local.azure_firewall_name
//  azure_firewall_privateip = local.azure_firewall_privateip
//  azure_firewall_rules_priority = 210
//  shared_datalake_id = local.shared_datalake_id
//  shared_datalake_name = local.shared_datalake_name
//}
