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