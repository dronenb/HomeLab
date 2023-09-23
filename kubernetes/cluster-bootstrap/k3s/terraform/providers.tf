terraform {
  # Workspace set to run locally. Configured in Terraform Cloud
  cloud {
    organization = "ben-dronen"
    workspaces {
      name = "k3s"
    }
  }
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.14"
    }
    http = {
      source = "hashicorp/http"
      version = "3.4.0"
    }
  }
}
provider "proxmox" {
  pm_tls_insecure = true
}
provider "http" {}