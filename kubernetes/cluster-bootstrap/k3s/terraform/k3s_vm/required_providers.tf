terraform {
  required_providers {
    # https://registry.terraform.io/providers/ansible/ansible/latest/docs
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    # https://registry.terraform.io/providers/bpg/proxmox/latest
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.44.0"
    }
  }
}