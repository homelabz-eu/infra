output "builder_ip" {
  description = "IP address of the builder VM"
  value       = var.vm_ip
}

output "builder_name" {
  description = "Name of the builder VM"
  value       = proxmox_vm_qemu.builder.name
}
