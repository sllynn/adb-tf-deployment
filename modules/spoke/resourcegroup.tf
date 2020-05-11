# create project resource group for databricks users
resource "azurerm_resource_group" "databricks_rg" {
  name     = "rg_${var.spoke_name}"
  location = var.spoke_location
  tags = {
    Owner = var.spoke_resource_owner
  }
}
