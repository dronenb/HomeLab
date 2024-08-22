terraform {
  required_providers {
    # https://registry.terraform.io/providers/bpg/proxmox/latest
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.63.0"
    }
    # https://registry.terraform.io/providers/community-terraform-providers/ignition/latest
    ignition = {
      source = "community-terraform-providers/ignition"
      version = "2.3.5"
    }
  }
}
