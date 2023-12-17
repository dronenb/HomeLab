terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.14"
    }
  }
}