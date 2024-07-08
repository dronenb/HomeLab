locals {
  proxmox_node = "fh-proxmox0"
}

data "http" "ssh_keys" {
  url = "https://github.com/dronenb.keys"
}

data "bitwarden_item_login" "cloudinit_credentials" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "24454e27-f2fa-4903-b42f-b00f017b0ad1"
}

resource "random_password" "k3s_server_token" {
  length  = 128
  special = true
}

resource "random_password" "k3s_agent_token" {
  length  = 128
  special = true
}

resource "proxmox_virtual_environment_file" "coreos_hookscript" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.proxmox_node

  source_raw {
    data      = file("coreos_hookscript.sh")
    file_name = "coreos_hookscript.sh"
  }

  provisioner "local-exec" {
    command = "ssh proxmox 'chmod +x /var/lib/vz/snippets/coreos_hookscript.sh'"
  }
}

module "k3s-server" {
  count              = 3
  source             = "./k3s_vm"
  vm_hostname        = "k3s-server-coreos${count.index}"
  proxmox_node       = local.proxmox_node
  vm_memory_mb       = 4096
  vm_disksize        = 20
  vm_tags            = ["k3s", "k3s-server"]
  cloudinit_username = data.bitwarden_item_login.cloudinit_credentials.username
  cloudinit_password = data.bitwarden_item_login.cloudinit_credentials.password
  cloudinit_ssh_keys = [trimspace(data.http.ssh_keys.response_body)]
  ipv4_addr          = { addr = format("%s%s", "10.91.1.", tostring(sum([9, count.index]))), mask = 24 }
  rendevous_host     = "10.91.1.9"
  cluster_vip        = "10.91.1.8"
  ipv4_gw            = "10.91.1.1"
  nameserver         = "10.91.1.1"
  vm_os              = "fcos"
  hook_script_id     = proxmox_virtual_environment_file.coreos_hookscript.id
  k3s_server_token   = random_password.k3s_server_token.result
  k3s_agent_token    = random_password.k3s_agent_token.result
}

# module "k3s-agent" {
#   count              = var.k3s_node_count
#   source             = "./proxmox_vm"
#   vm_hostname        = "k3s-agent-test${count.index}"
#   proxmox_node       = "fh-proxmox0"
#   cloudinit_username = var.cloudinit_username
#   cloudinit_password = var.cloudinit_password
#   ipv4_addr          = { addr = format("%s%s", "10.91.1.", tostring(sum([4, count.index, var.k3s_master_count]))), mask = 24 }
#   ipv4_gw            = "10.91.1.1"
#   nameserver         = "10.91.1.1"
#   vm_memory_mb       = 2048
#   vm_disksize        = "20G"
#   vmid               = sum([105, count.index, var.k3s_master_count])
#   vm_tags            = ["k3s", "k3s-node"]
#   vm_os              = "debian"
#   ansible_groups     = ["${ansible_group.k3s-node.name}"]
# }
