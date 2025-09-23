output "public_ip" {
  description = "La IP pública de la máquina virtual."
  value       = azurerm_public_ip.pip.ip_address
}