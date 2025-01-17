locals {
  proxmox_node = "fh-proxmox0"
}

data "bitwarden_item_login" "f5-ve-info" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "d44d43f6-8d15-4fae-a651-b25a013fe8c9"
}

data "http" "ssh_keys" {
  url = "https://github.com/dronenb.keys"
}

module "f5-ve-server" {
  count          = 2
  source         = "./f5_ve_vm"
  vm_hostname    = "f5-bigip-ve-${count.index}"
  proxmox_node   = local.proxmox_node
  vm_memory_mb   = 4096
  vm_disksize_gb = 100
  vm_tags        = ["k3s", "k3s-server"]
  root_password  = data.bitwarden_item_login.f5-ve-info.password
  ipv4_addr      = { addr = format("%s%s", "10.91.1.", tostring(sum([12, count.index]))), mask = 24 }
  ipv4_gw        = "10.91.1.1"
  nameserver     = "10.91.1.1"
  search_domains = [
    "fh.dronen.house"
  ]
  vm_os = "f5-big-ip-ve"
}
