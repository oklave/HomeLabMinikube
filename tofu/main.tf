resource "proxmox_virtual_environment_vm" "minikube" {
  node_name = var.proxmox_node
  name      = "minikube-lab"
  vm_id     = var.vm_id

  # Ресурсы под твой сервер
  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  # Клонирование из шаблона
  clone {
    vm_id = var.template_id
  }

  # Cloud-Init
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      keys     = [var.ssh_public_key]
      username = "ubuntu"
    }
  }

  # Сеть
  network_device {
    bridge = var.network_bridge
  }

  # QEMU Agent нужен для корректного определения IP
  agent {
    enabled = true
  }

  # Защита от пересоздания при изменении DHCP-IP или дисков
  lifecycle {
    ignore_changes = [disk, network_device, initialization[0].ip_config]
  }
}