terraform {
  required_version = ">= 1.11.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.105"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.19"
    }
  }
}
