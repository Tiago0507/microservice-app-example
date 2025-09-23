output "vm_public_ip" {
  description = "La IP pública de la máquina virtual."
  value       = module.vm.public_ip
}