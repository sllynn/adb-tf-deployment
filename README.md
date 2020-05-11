# adb-tf-deployment

## Terraform templates for Azure Databricks deployment

This repository contains a set of sample Terraform templates describing a deployment of Azure Databricks in line with the advice in [this](https://databricks.com/blog/2020/03/27/data-exfiltration-protection-with-azure-databricks.html) article.

The key components are:

1. A *hub* resource group containing an Azure Firewall instance with the application and network rules required to access the Databricks shared resources in the UK South region. If required, routes back to the corporate network (via e.g. ExpressRoute) would be collocated with the Azure Firewall in this hub VNET.
2. A *shared* resource group containing an Azure Data Lake Storage account which can be accessed by the Databricks workspace using Microsoft's PrivateLink service. More shared services can be added here and accessed in the same way (e.g. a shared SQL DB instance). 
3. A project- or business unit-specific resource group (*spoke*) containing the Databricks workspace and configured with routes back to the firewall and out to the UK South control plane, together with the firewall rules required for access to the Databricks file system. Azure Active Directory resources (e.g. groups and service principals) could also be add to this module to configure access to the Databricks workspace and to resources in the *shared* resource group.

To create a new analytics environment within your subscription, add a new module block to the `spokes.tf` template. 