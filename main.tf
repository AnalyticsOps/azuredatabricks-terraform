terraform {
  required_providers {
    databricks = {
      source = "databrickslabs/databricks"
      version = "0.3.2"
    }
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

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.this.id
  azure_client_id             = var.client_id
  azure_client_secret         = var.client_secret
  azure_tenant_id             = var.tenant_id
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
  depends_on = [azurerm_databricks_workspace.this]
}

data "databricks_node_type" "smallest" {
  local_disk = false
  depends_on = [azurerm_databricks_workspace.this]
}

resource "databricks_cluster" "cluster" {
  cluster_name            = "default_cluster"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = data.databricks_node_type.smallest.id
  autotermination_minutes = 20
  autoscale {
    min_workers = 1
    max_workers = 8
  }
  depends_on = [azurerm_databricks_workspace.this]
}

resource "databricks_secret_scope" "this" {
  name = "terraform"
  depends_on = [azurerm_databricks_workspace.this]
}

resource "databricks_secret" "this" {
  key          = "service_principal_key"
  string_value = var.client_secret
  scope        = databricks_secret_scope.this.name
  depends_on = [azurerm_databricks_workspace.this]
}

resource "azurerm_role_assignment" "this" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  depends_on = [azurerm_databricks_workspace.this]
}

resource "databricks_azure_adls_gen2_mount" "this" {
  cluster_id             = databricks_cluster.cluster.id
  storage_account_name   = var.storage_account_name
  container_name         = "trainingdata"
  mount_name             = "data"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  client_id              = data.azurerm_client_config.current.client_id
  client_secret_scope    = databricks_secret_scope.this.name
  client_secret_key      = databricks_secret.this.key
  initialize_file_system = true
  depends_on = [azurerm_databricks_workspace.this]
}
