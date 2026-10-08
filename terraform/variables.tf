variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "cloudinfra"
}

variable "location" {
  description = "Azure region to deploy into. Must be one of the regions allowed on your subscription (check with: az policy assignment list)."
  type        = string
  default     = "swedencentral"
}

variable "environment" {
  description = "Deployment environment tag (dev/prod)."
  type        = string
  default     = "dev"
}

variable "app_image" {
  description = "Public image to deploy, without the tag (e.g. a Docker Hub repo)."
  type        = string
  default     = "docker.io/nafiulhamim/dat515-app"
}

variable "app_version" {
  description = "Tag of the app image to deploy."
  type        = string
  default     = "latest"
}

variable "db_name" {
  description = "MySQL database name."
  type        = string
  default     = "webapp"
}

variable "db_user" {
  description = "MySQL application user."
  type        = string
  default     = "webuser"
}

variable "db_password" {
  description = "MySQL application user password. Leave blank to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_root_password" {
  description = "MySQL root password. Leave blank to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}
