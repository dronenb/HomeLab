terraform {
  required_providers {
    # https://registry.terraform.io/providers/ansible/ansible/latest/docs
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
    # https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.7.2"
    }
    # https://registry.terraform.io/providers/bpg/proxmox/latest
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.46.3"
    }
    # https://registry.terraform.io/providers/hashicorp/http/latest
    http = {
      source  = "hashicorp/http"
      version = "3.4.1"
    }
    # https://registry.terraform.io/providers/hashicorp/random/latest
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
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
