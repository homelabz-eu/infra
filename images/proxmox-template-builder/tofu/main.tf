resource "proxmox_vm_qemu" "builder" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.clone_template
  full_clone  = true
  agent       = 1
  cores       = var.cores
  sockets     = 1
  memory      = var.memory
  cpu_type    = "host"
  onboot      = false
  vm_state    = "running"
  boot        = "order=scsi0"
  scsihw      = "virtio-scsi-single"
  tags        = "packer,ephemeral"

  ciuser     = "suporte"
  sshkeys    = var.ssh_public_key
  ipconfig0  = "ip=${var.vm_ip}/24,gw=192.168.1.1"
  nameserver = "192.168.1.3"
  skip_ipv6  = true
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "data2"
          size    = var.disk_size
          format  = "raw"
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "data2"
        }
      }
    }
  }

  network {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
    id       = 0
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      bootdisk,
      smbios,
      clone,
      full_clone,
    ]
  }
}
