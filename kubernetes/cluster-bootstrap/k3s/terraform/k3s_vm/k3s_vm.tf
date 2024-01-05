data "proxmox_virtual_environment_vms" "existing_vms" {}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = <<EOF
#cloud-config
chpasswd:
  list: |
    ${var.cloudinit_username}:${var.cloudinit_password}
  expire: false
hostname: ${var.vm_hostname}
packages:
  - qemu-guest-agent
users:
  - name: ${var.cloudinit_username}
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      ${yamlencode(var.cloudinit_ssh_keys)}
    sudo: ALL=(ALL) NOPASSWD:ALL
runcmd:
  - ["/usr/sbin/reboot"]
EOF
# The runcmd to reboot is there to make the machine reboot after installation of qemu-guest-agent, otherwise terraform may hang since proxmox may not detect the agent is functional
    file_name = "${var.vm_hostname}.cloud-config.yaml"
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

    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }
  agent {
    enabled = true # this will cause terraform operations to hang if not set
  }
  name      = var.vm_hostname
  tags      =     sort(
    concat(
      ["${var.vm_os}", "opentofu"],
      var.vm_tags,
    )
  )
  bios      = "ovmf"
  node_name = var.proxmox_node
  machine   = "q35"
  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    interface = "scsi0"
    size = var.vm_disksize
  }
  efi_disk {
    type = "4m"
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
    full  = true
  }

  network_device {
    bridge = "vmbr0"
    model = "virtio"
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    version = "v2.0"
  }

  serial_device {}
}

resource "ansible_host" "host" {
  name   = var.vm_hostname
  groups = var.ansible_groups
  variables = {
    ansible_host        = var.ipv4_addr.addr
    netplan_netmask     = var.ipv4_addr.mask
    netplan_nameserver  = var.nameserver
    netplan_gateway     = var.ipv4_gw
    k3s_node_ip         = var.ipv4_addr.addr
    # netplan_macaddr     = "${proxmox_vm_qemu.vm.network[0].macaddr}"
    ansible_user        = "{{ lookup('community.general.bitwarden','k3s_cloudinit',field='username')|first }}"
    ansible_become_pass = "{{ lookup('community.general.bitwarden','k3s_cloudinit',field='password')|first }}"
  }
}