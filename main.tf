terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=2.62.0"
    }
  }
}


locals {
  resource_postfix             = "${var.project_name}-${var.resource_number}"
  resource_postfix_restricted  = "${var.project_name}${var.resource_number}"
}


data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name     = var.resource_group_name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${local.resource_postfix}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
}


resource "azurerm_subnet" "priv_databricks_subnet" {
  name                 = "snet-priv-databricks"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_priv" {
  subnet_id                 = azurerm_subnet.priv_databricks_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet" "pub_databricks_subnet" {
  name                 = "snet-pub-databricks"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_pub" {
  subnet_id                 = azurerm_subnet.pub_databricks_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_databricks_workspace" "this" {
  name                = "db-${local.resource_postfix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku                 = "premium"
  custom_parameters {
    virtual_network_id  = var.virtual_network_id
    private_subnet_name = azurerm_subnet.priv_databricks_subnet.name
    public_subnet_name = azurerm_subnet.pub_databricks_subnet.name
  }
}