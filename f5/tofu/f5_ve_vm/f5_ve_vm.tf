# https://clouddocs.f5.com/cloud/public/v1/shared/cloudinit.html
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "f5-ve-cloud-init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "fh-proxmox0"

  source_raw {
    data = format("#cloud-config\n%s", yamlencode({
      chpasswd = {
        list = "root:${var.root_password}\nadmin:${var.root_password}"
        expire = false
      }
      write_files = [
        {
          path = "/config/revoke-license.sh"
          permissions = 0755
          owner = "root:root"
          content = <<EOF
#!/usr/bin/env bash
# Wait for MCPD to be up before running tmsh commands
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready
echo "Y" | tmsh revoke sys license
EOF
        },
        {
          path = "/config/management-ip.sh"
          permissions = 0755
          owner = "root:root"
          content = <<EOF
#!/usr/bin/env bash
# Wait for MCPD to be up before running tmsh commands
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready
tmsh save /sys config
tmsh modify sys global-settings mgmt-dhcp disabled
tmsh create sys management-ip ${var.ipv4_addr.addr}/${var.ipv4_addr.mask}
tmsh create sys management-route default gateway ${var.ipv4_gw}
tmsh create net self self_1nic address ${var.ipv4_addr.addr}/${var.ipv4_addr.mask} vlan internal allow-service default traffic-group traffic-group-local-only
tmsh create net route default network default gw ${var.ipv4_gw}
tmsh save /sys config
EOF
        },
      ]
      runcmd = [
        "/config/management-ip.sh &",
      ]
      tmos_declared = {
        enabled = true
        # Unfortunately seems like these packages are not appropriate signed, thus has to be disabled
        icontrollx_trusted_sources = false
        icontrollx_package_urls = [
          "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.46.0/f5-declarative-onboarding-1.46.0-7.noarch.rpm",
          "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.53.0/f5-appsvcs-3.53.0-7.noarch.rpm"
        ]
        # https://clouddocs.f5.com/products/extensions/f5-declarative-onboarding/latest/
        do_declaration = {
          schemaVersion= "1.46.0"
          class = "Device"
          async = true
          label = "Cloudinit Onboarding"
          Common = {
            class = "Tenant"
            hostname = "${var.vm_hostname}.${var.search_domains[0]}"
            # myLicense = {
            #   class = "License"
            #   licenseType = "regKey"
            #   regKey = "${data.bitwarden_item_login.f5-ve-info.field[0].hidden}"
            # }
            myDns = {
              class = "DNS"
              nameServers = [
                var.nameserver
              ]
              search = var.search_domains
            }
          }
        }
      }
    }))
    file_name = "f5-ve-cloud-init-${var.vm_hostname}.yaml"
  }
}

data "proxmox_virtual_environment_vms" "existing_vms" {}

resource "proxmox_virtual_environment_vm" "f5_ve_server" {
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.f5-ve-cloud-init.id
    ip_config {
      ipv4 {
        address = "${var.ipv4_addr.addr}%{if var.ipv4_addr.mask != ""}/${var.ipv4_addr.mask}%{endif}"
        gateway = var.ipv4_gw
      }
    }
  }
  agent {
    enabled = false # this will cause terraform operations to hang if the Qemu agent doesn't install correctly!
  }
  name = var.vm_hostname
  tags = sort(
    concat(
      ["${var.vm_os}", "tofu"],
      var.vm_tags,
    )
  )
  bios      = "seabios"
  node_name = "fh-proxmox0"
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
    size      = var.vm_disksize_gb
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
  vga {
    memory = 16
    type   = "std"
  }
  serial_device {}
}
