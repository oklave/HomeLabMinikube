output "vm_ip" {
  description = "IP-адрес ВМ (первый IPv4)"
  value       = proxmox_virtual_environment_vm.minikube.ipv4_addresses[0][0]
}

output "ssh_command" {
  value = "ssh ubuntu@${proxmox_virtual_environment_vm.minikube.ipv4_addresses[0][0]}"
}