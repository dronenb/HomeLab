data "http" "ssh_keys" {
  url = "https://github.com/dronenb.keys"
}

resource "proxmox_vm_qemu" "vm" {
  agent      = 1
  bios       = "ovmf"
  clone      = "${var.vm_os}-latest"
  ciuser     = var.cloudinit_username
  cipassword = var.cloudinit_password
  full_clone = true
  ipconfig0 = join(
    ",",
    compact([
      "ip=${var.ipv4_addr.addr}%{if var.ipv4_addr.mask != ""}/${var.ipv4_addr.mask}%{endif}",
      "%{if var.ipv4_gw != ""}gw=${var.ipv4_gw}%{endif}",
      "ip6=${var.ipv6_addr.addr}%{if var.ipv6_addr.mask != ""}/${var.ipv6_addr.mask}%{endif}",
      "%{if var.ipv6_gw != ""}gw6=${var.ipv6_gw}%{endif}",
    ])
  )
  memory     = tostring(var.vm_memory_mb)
  name       = var.vm_hostname # Required
  nameserver = var.nameserver
  onboot     = true
  oncreate   = false # This is deprecated after 2.9.14
  # vm_state    = running # This will work after 2.9.14 and replace oncreate
  os_type = "cloud-init"
  qemu_os = "l26"
  scsihw  = "virtio-scsi-pci"
  sshkeys = data.http.ssh_keys.response_body
  tags = join(
    ";",
    sort(
      concat(
        ["${var.vm_os}", "terraform"],
        var.vm_tags,
      )
    )
  )
  target_node = var.proxmox_node # Required
  vmid        = var.vmid

  # Must explicitly specify all options because of bug
  # https://github.com/Telmate/terraform-provider-proxmox/issues/704
  # https://github.com/Telmate/terraform-provider-proxmox/issues/742
  # Comment out this block -> Run Terraform apply -> Uncomment block
  disk {
    backup             = true
    cache              = "none"
    file               = "vm-${var.vmid}-disk-0"
    format             = "raw"
    iops               = 0
    iops_max           = 0
    iops_max_length    = 0
    iops_rd            = 0
    iops_rd_max        = 0
    iops_rd_max_length = 0
    iops_wr            = 0
    iops_wr_max        = 0
    iops_wr_max_length = 0
    iothread           = 0
    mbps               = 0
    mbps_rd            = 0
    mbps_rd_max        = 0
    mbps_wr            = 0
    mbps_wr_max        = 0
    replicate          = 0
    size               = var.vm_disksize
    slot               = 0
    ssd                = 0
    storage            = "local-lvm"
    type               = "scsi"
    volume             = "local-lvm:vm-${var.vmid}-disk-0"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}

resource "ansible_host" "host" {
  name   = var.vm_hostname
  groups = var.ansible_groups
  variables = {
    ansible_host        = "${var.ipv4_addr.addr}"
    netplan_netmask     = "${var.ipv4_addr.mask}"
    netplan_nameserver  = "${var.nameserver}"
    netplan_gateway     = "${var.ipv4_gw}"
    netplan_macaddr     = "${proxmox_vm_qemu.vm.network[0].macaddr}"
    ansible_user        = "{{ lookup('ansible.builtin.env', 'TF_VAR_cloudinit_username') }}"
    ansible_become_pass = "{{ lookup('ansible.builtin.env', 'TF_VAR_cloudinit_password') }}"
  }
}