output "app_url" {
  description = "Public URL of the deployed app."
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "resource_group" {
  description = "Resource group holding all resources."
  value       = azurerm_resource_group.main.name
}

output "container_registry_login_server" {
  description = "Login server for the container registry (used to push images)."
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  value = azurerm_container_registry.main.admin_username
}

output "container_registry_admin_password" {
  value     = azurerm_container_registry.main.admin_password
  sensitive = true
}

output "db_password" {
  value     = local.db_password
  sensitive = true
}

output "db_root_password" {
  value     = local.db_root_password
  sensitive = true
}
