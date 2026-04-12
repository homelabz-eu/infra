variable "proxmox_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.248:8006/api2/json"
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "vm_name" {
  description = "Name for the builder VM"
  type        = string
  default     = "packer-builder"
}

variable "target_node" {
  description = "Proxmox node to create the VM on"
  type        = string
  default     = "node03"
}

variable "vm_ip" {
  description = "Static IP for the builder VM"
  type        = string
  default     = "192.168.1.170"
}

variable "clone_template" {
  description = "Template to clone for the builder VM"
  type        = string
  default     = "ubuntu24-cloudinit"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 8192
}

variable "disk_size" {
  description = "Disk size for the builder VM"
  type        = string
  default     = "50G"
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"
}
