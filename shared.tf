# create example resource group for shared resources e.g. corp data lake
resource "azurerm_resource_group" "shared_rg" {
  name     = "rg_shared"
  location = var.shared_location
  tags = {
    Owner = var.shared_resource_owner
  }
}

resource "azurerm_storage_account" "shared_datalake" {
  name = "shareddatalake"
  resource_group_name = azurerm_resource_group.shared_rg.name
  account_replication_type = "GRS"
  account_tier = "Standard"
  location = azurerm_resource_group.shared_rg.location
}