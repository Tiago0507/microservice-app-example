variable "resource_group_name" {
  description = "El nombre del grupo de recursos."
  type        = string
  default     = "microservices-rg"
}

variable "location" {
  description = "La región de Azure donde se crearán los recursos."
  type        = string
  default     = "eastus2"
}

variable "vnet_name" {
  description = "El nombre de la red virtual."
  type        = string
  default     = "microservices-vnet"
}

variable "subnet_name" {
  description = "El nombre de la subred."
  type        = string
  default     = "microservices-subnet"
}

variable "admin_username" {
  description = "El nombre de usuario para la VM."
  type        = string
  default     = "adminuser"
}

variable "admin_password" {
  description = "La contraseña para la VM."
  type        = string
  sensitive   = true
}