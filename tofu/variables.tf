variable "proxmox_host" {
  description = "IP или домен Proxmox VE"
  type        = string
}

variable "proxmox_api_token" {
  description = "API Token user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Node name Proxmox"
  type        = string
  default     = "srv-1"
}

variable "template_id" {
  description = "ID Cloud-Init template (default - 9000)"
  type        = number
  default     = 9000
}

variable "vm_id" {
  description = "ID новVM"
  type        = number
  default     = 101
}

variable "ssh_public_key" {
  description = "ssh public key"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge Proxmox"
  type        = string
  default     = "vmbr0"
}
