locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 20
  special = false
}

locals {
  db_password = var.db_password != "" ? var.db_password : random_password.db_password[0].result
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_prefix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# --- Database tier: Azure Database for MySQL Flexible Server ---

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "mysql-${local.name_prefix}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  administrator_login    = var.db_user
  administrator_password = local.db_password
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"
  backup_retention_days  = 7

  storage {
    size_gb = 20
  }
}

resource "azurerm_mysql_flexible_database" "main" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Lets any Azure resource (including this Container App) reach the server;
# Flexible Server has no VNET-integrated option on the Burstable tier that's
# simpler to set up for a short-lived demo than public access + firewall rules.
resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "allow-azure-services"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow_my_ip" {
  count               = var.my_ip_address != "" ? 1 : 0
  name                = "allow-my-ip"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  start_ip_address    = var.my_ip_address
  end_ip_address      = var.my_ip_address
}

# --- Cache tier: Azure Managed Redis ---
# (Azure Cache for Redis is being retired; new deployments must use this instead.)

resource "azurerm_managed_redis" "main" {
  name                = "redis-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "Balanced_B0"
  # Defaults to true, which runs 2 nodes (2x cost) - not needed for a demo.
  high_availability_enabled = false

  default_database {
    client_protocol = "Encrypted"
    # Defaults to false (Entra ID auth only); the app authenticates with a
    # password, so access-key auth needs to be turned on explicitly.
    access_keys_authentication_enabled = true
  }
}

# --- App tier: Go web service, public ---

resource "azurerm_container_app" "app" {
  name                         = "app"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  secret {
    name  = "db-password"
    value = local.db_password
  }
  secret {
    name  = "redis-password"
    value = azurerm_managed_redis.main.default_database[0].primary_access_key
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "app"
      image  = "${var.app_image}:${var.app_version}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "DB_HOST"
        value = azurerm_mysql_flexible_server.main.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "3306"
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "DB_TLS_MODE"
        value = "true"
      }
      env {
        name  = "REDIS_HOST"
        value = azurerm_managed_redis.main.hostname
      }
      env {
        name  = "REDIS_PORT"
        value = tostring(azurerm_managed_redis.main.default_database[0].port)
      }
      env {
        name        = "REDIS_PASSWORD"
        secret_name = "redis-password"
      }
      env {
        name  = "REDIS_TLS"
        value = "true"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [
    azurerm_mysql_flexible_database.main,
    azurerm_mysql_flexible_server_firewall_rule.azure_services,
  ]
}
