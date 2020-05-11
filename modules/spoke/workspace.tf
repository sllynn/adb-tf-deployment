# create the workspace itself into the VNET created above
resource "azurerm_databricks_workspace" "databricks_workspace" {
  name = "adb_${var.spoke_name}"
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