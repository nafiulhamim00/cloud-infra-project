variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "cloudinfra"
}

variable "location" {
  description = "Azure region to deploy into."
  type        = string
  default     = "norwayeast"
}

variable "environment" {
  description = "Deployment environment tag (dev/prod)."
  type        = string
  default     = "dev"
}

variable "app_version" {
  description = "Tag of the app image to deploy from the container registry."
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
