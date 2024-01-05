terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.43.0"
    }
  }
}