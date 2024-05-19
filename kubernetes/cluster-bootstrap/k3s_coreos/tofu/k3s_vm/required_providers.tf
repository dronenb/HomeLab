terraform {
  required_providers {
    # https://registry.terraform.io/providers/bpg/proxmox/latest
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.57.0"
    }
    ignition = {
      source = "community-terraform-providers/ignition"
      version = "2.3.5"
    }
  }
}
