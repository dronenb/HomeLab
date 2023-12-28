data "proxmox_virtual_environment_vms" "existing_vms" {}
resource "proxmox_virtual_environment_vm" "k3s_server_vm" {
  initialization {
    dns {
      # servers = [var.nameserver] # This is new and isn't working as expected: https://github.com/bpg/terraform-provider-proxmox/issues/841
      server = var.nameserver
    }
    ip_config {
      ipv4 {
        address = "${var.ipv4_addr.addr}%{if var.ipv4_addr.mask != ""}/${var.ipv4_addr.mask}%{endif}"
        gateway = var.ipv4_gw
      }
    }

    user_account {
      keys     = var.cloudinit_ssh_keys
      password = var.cloudinit_password
      username = var.cloudinit_username
    }
  }
  # agent {
  #   enabled = true
  # }
  name      = var.vm_hostname
  tags      =     sort(
    concat(
      ["${var.vm_os}", "terraform"],
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
    ansible_host        = "${var.ipv4_addr.addr}"
    netplan_netmask     = "${var.ipv4_addr.mask}"
    netplan_nameserver  = "${var.nameserver}"
    netplan_gateway     = "${var.ipv4_gw}"
    k3s_version         = "${var.k3s_version}"
    # netplan_macaddr     = "${proxmox_vm_qemu.vm.network[0].macaddr}"
    ansible_user        = "{{ lookup('community.general.bitwarden','k3s_cloudinit',field='username')|first }}"
    ansible_become_pass = "{{ lookup('community.general.bitwarden','k3s_cloudinit',field='password')|first }}"
  }
}