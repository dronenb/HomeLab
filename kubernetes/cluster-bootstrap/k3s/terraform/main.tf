resource "ansible_group" "k3s-master" {
  name = "k3s_master"
}

resource "ansible_group" "k3s-node" {
  name = "k3s_node"
}

module k3s-master {
  count = var.k3s_master_count
  source = "./proxmox_vm"
  vm_hostname = "k3s-master${count.index}"
  proxmox_node = "fh-proxmox0"
  cloudinit_username = var.cloudinit_username
  cloudinit_password = var.cloudinit_password
  ipv4_addr = {addr=format("%s%s", "10.91.1.", tostring(sum([4, count.index]))),mask=24}
  ipv4_gw = "10.91.1.1"
  nameserver = "10.91.1.1"
  vm_memory_mb = 2048
  vm_disksize = "20G"
  vmid = sum([105, count.index])
  vm_tags = ["k3s", "k3s-master"]
  vm_os = "debian"
  ansible_groups = ["${ansible_group.k3s-master.name}"]
}

module k3s-node {
  count = var.k3s_node_count
  source = "./proxmox_vm"
  vm_hostname = "k3s-node${count.index}"
  proxmox_node = "fh-proxmox0"
  cloudinit_username = var.cloudinit_username
  cloudinit_password = var.cloudinit_password
  ipv4_addr = {addr=format("%s%s", "10.91.1.", tostring(sum([4, count.index, var.k3s_master_count]))),mask=24}
  ipv4_gw = "10.91.1.1"
  nameserver = "10.91.1.1"
  vm_memory_mb = 2048
  vm_disksize = "20G"
  vmid = sum([105, count.index, var.k3s_master_count])
  vm_tags = ["k3s", "k3s-node"]
  vm_os = "debian"
  ansible_groups = ["${ansible_group.k3s-node.name}"]
}