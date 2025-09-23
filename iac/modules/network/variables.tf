variable "resource_group_name" {
  description = "El nombre del grupo de recursos."
  type        = string
}

variable "location" {
  description = "La región de Azure."
  type        = string
}

variable "vnet_name" {
  description = "El nombre de la red virtual."
  type        = string
}

variable "subnet_name" {
  description = "El nombre de la subred."
  type        = string
}