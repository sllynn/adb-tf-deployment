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