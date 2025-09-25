variable "resource_group_name" {
  description = "El nombre del grupo de recursos."
  type        = string
}

variable "location" {
  description = "La región de Azure."
  type        = string
}

variable "subnet_id" {
  description = "El ID de la subred."
  type        = string
}

variable "admin_username" {
  description = "El nombre de usuario para la VM."
  type        = string
}

variable "admin_password" {
  description = "La contraseña para la VM."
  type        = string
  sensitive   = true
}