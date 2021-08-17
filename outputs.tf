output "subnets" {
  value = [
      azurerm_subnet.priv_databricks_subnet.id,
      azurerm_subnet.pub_databricks_subnet.id
  ]
}

output "databrick_id" {
  value = azurerm_databricks_workspace.this.id
}
