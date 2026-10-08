locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 20
  special = false
}

resource "random_password" "db_root_password" {
  count   = var.db_root_password == "" ? 1 : 0
  length  = 24
  special = false
}

locals {
  db_password      = var.db_password != "" ? var.db_password : random_password.db_password[0].result
  db_root_password = var.db_root_password != "" ? var.db_root_password : random_password.db_root_password[0].result
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                = replace("acr${local.name_prefix}", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
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

# --- Database tier (MySQL, internal only) ---

resource "azurerm_container_app" "database" {
  name                         = "database"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  secret {
    name  = "mysql-root-password"
    value = local.db_root_password
  }
  secret {
    name  = "mysql-password"
    value = local.db_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "mysql"
      image  = "mysql:8.0"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "MYSQL_ROOT_PASSWORD"
        secret_name = "mysql-root-password"
      }
      env {
        name  = "MYSQL_DATABASE"
        value = var.db_name
      }
      env {
        name  = "MYSQL_USER"
        value = var.db_user
      }
      env {
        name        = "MYSQL_PASSWORD"
        secret_name = "mysql-password"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 3306
    transport        = "tcp"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# --- Cache tier (Redis, internal only) ---

resource "azurerm_container_app" "cache" {
  name                         = "cache"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "redis"
      image  = "redis:7-alpine"
      cpu    = 0.25
      memory = "0.5Gi"
      args   = ["redis-server", "--appendonly", "yes"]
    }
  }

  ingress {
    external_enabled = false
    target_port      = 6379
    transport        = "tcp"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# --- App tier (Go web service, public) ---

locals {
  database_fqdn = "${azurerm_container_app.database.name}.internal.${azurerm_container_app_environment.main.default_domain}"
  cache_fqdn    = "${azurerm_container_app.cache.name}.internal.${azurerm_container_app_environment.main.default_domain}"
}

resource "azurerm_container_app" "app" {
  name                         = "app"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "registry-password"
  }

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.main.admin_password
  }
  secret {
    name  = "db-password"
    value = local.db_password
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "app"
      image  = "${azurerm_container_registry.main.login_server}/dat515-app:${var.app_version}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "DB_HOST"
        value = local.database_fqdn
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
        name  = "REDIS_HOST"
        value = local.cache_fqdn
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
    azurerm_container_app.database,
    azurerm_container_app.cache,
  ]
}
