terraform {
  required_providers {
    proxmox = {
      source  = "registry.terraform.io/bpg/proxmox"
      version = "~> 0.65"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:8006/api2/json"
  api_token = var.proxmox_api_token
  insecure  = true
}