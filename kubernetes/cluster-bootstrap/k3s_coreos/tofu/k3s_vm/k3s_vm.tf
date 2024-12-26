data "proxmox_virtual_environment_vms" "existing_vms" {}

data "ignition_file" "k3s_server_config" {
  path = "/etc/rancher/k3s/config.yaml.d/server.yaml"
  content {
    content = var.ipv4_addr.addr == var.rendevous_host ? "cluster-init: true\ntoken: '${var.k3s_server_token}'\ntls-san:\n  - '${var.cluster_vip}'" : "server: 'https://${var.rendevous_host}:6443'\ntoken: '${var.k3s_server_token}'\ntls-san:\n  - '${var.cluster_vip}'"
  }
}

data "ignition_file" "k3s_agent_config" {
  path = "/etc/rancher/k3s/config.yaml.d/agent.yaml"
  content {
    content = "agent-token: '${var.k3s_agent_token}'\n"
  }
}

data "ignition_config" "ignition_config" {
  files = [
    sensitive(data.ignition_file.k3s_server_config.rendered),
    sensitive(data.ignition_file.k3s_agent_config.rendered),
  ]
  merge {
    source = format("data:;base64,%s", base64encode(file("/private/tmp/k3s_init/k3s.ign")))
  }
}

resource "proxmox_virtual_environment_file" "base_ignition" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data      = sensitive(data.ignition_config.ignition_config.rendered)
    file_name = "${var.vm_hostname}-base.ign"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_server_vm" {
  initialization {
    dns {
      servers = [var.nameserver]
    }
    ip_config {
      ipv4 {
        address = "${var.ipv4_addr.addr}%{if var.ipv4_addr.mask != ""}/${var.ipv4_addr.mask}%{endif}"
        gateway = var.ipv4_gw
      }
    }
    user_account {
      keys     = var.cloudinit_ssh_keys
      username = var.cloudinit_username
      password = var.cloudinit_password
    }
  }
  agent {
    enabled = true # this will cause terraform operations to hang if the Qemu agent doesn't install correctly!
  }
  name = var.vm_hostname
  tags = sort(
    concat(
      ["${var.vm_os}", "tofu"],
      var.vm_tags,
    )
  )
  bios      = "ovmf"
  node_name = var.proxmox_node
  machine   = "q35"
  memory {
    dedicated = var.vm_memory_mb
  }

  cpu {
    type  = "host"
    cores = "2"
  }

  disk {
    interface = "scsi0"
    size      = var.vm_disksize
  }
  # Volume for Ceph
  disk {
    interface = "scsi1"
    size      = 100
    file_format = "raw"
  }
  efi_disk {
    type        = "4m"
    file_format = "raw"
  }
  clone {
    vm_id = lookup(
      zipmap(
        data.proxmox_virtual_environment_vms.existing_vms.vms[*].name,
        data.proxmox_virtual_environment_vms.existing_vms.vms[*].vm_id
      ),
      "${var.vm_os}-latest"
    )
    full = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }
  kvm_arguments = "-fw_cfg name=opt/com.coreos/config,file=/var/lib/vz/snippets/${var.vm_hostname}.ign"
  vga {
    memory  = 16
    type    = "std"
  }
  # serial_device {}
  hook_script_file_id = var.hook_script_id
}
