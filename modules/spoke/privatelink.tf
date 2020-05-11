# create a private endpoint for shared data lake account
resource "azurerm_private_endpoint" "storage_endpoint" {
  name = "sa_datalake_endpoint"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  location = azurerm_resource_group.databricks_rg.location
  subnet_id = azurerm_subnet.databricks_privatelink_subnet.id
  private_service_connection {
    name = "sa_shared_datalake_psc"
    is_manual_connection = false
    private_connection_resource_id = var.shared_datalake_id #azurerm_storage_account.shared_datalake.id
    subresource_names = ["dfs"]
  }
}

# add a private endpoint and private dns zone for accessing shared ADLS account using privatelink
resource "azurerm_private_dns_zone" "databricks_dns" {
  name = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

data "azurerm_private_endpoint_connection" "shared_datalake_connection" {
  depends_on = [azurerm_private_endpoint.storage_endpoint]
  name = azurerm_private_endpoint.storage_endpoint.name
  resource_group_name = azurerm_resource_group.databricks_rg.name
}

resource "azurerm_private_dns_a_record" "shared_datalake_dns" {
  name = var.shared_datalake_name
  depends_on = [azurerm_private_endpoint.storage_endpoint, data.azurerm_private_endpoint_connection.shared_datalake_connection]
  resource_group_name = azurerm_resource_group.databricks_rg.name
  zone_name = azurerm_private_dns_zone.databricks_dns.name
  ttl = 300
//  records = [azurerm_private_endpoint.storage_endpoint.private_service_connection[0].private_ip_address]
  records = [data.azurerm_private_endpoint_connection.shared_datalake_connection.private_service_connection[0].private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name = "databricks_storage_endpoint_link"
  resource_group_name = azurerm_resource_group.databricks_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.databricks_dns.name
  virtual_network_id = azurerm_virtual_network.databricks_vnet.id
}