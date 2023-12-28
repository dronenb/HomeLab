terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.7.2"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.41.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.1"
    }
  }
}
provider "http" {}
provider "bitwarden" {}
data "bitwarden_item_login" "proxmox_credentials" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "d96bdd64-86fb-438f-81a7-afae0117ec76"
}
provider "proxmox" {
  endpoint = data.bitwarden_item_login.proxmox_credentials.uri[0].value
  username = "${data.bitwarden_item_login.proxmox_credentials.username}@pam"
  password = data.bitwarden_item_login.proxmox_credentials.password
  insecure = true
  ssh {
    agent    = true
    username = data.bitwarden_item_login.proxmox_credentials.username
  }
}
