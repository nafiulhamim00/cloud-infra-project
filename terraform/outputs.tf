output "app_url" {
  description = "Public URL of the deployed app."
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "resource_group" {
  description = "Resource group holding all resources."
  value       = azurerm_resource_group.main.name
}

output "db_password" {
  value     = local.db_password
  sensitive = true
}

output "mysql_fqdn" {
  description = "MySQL server hostname, for connecting with a MySQL client."
  value       = azurerm_mysql_flexible_server.main.fqdn
}
