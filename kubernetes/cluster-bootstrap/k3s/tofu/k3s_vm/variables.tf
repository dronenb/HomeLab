variable "cloudinit_username" {
  type = string
}

variable "cloudinit_password" {
  type      = string
  sensitive = true
}

variable "cloudinit_ssh_keys" {
  type    = list(string)
  default = []
}

variable "ipv4_addr" {
  type = object({
    addr = string
    mask = string
  })
  default = {
    addr = "dhcp"
    mask = ""
  }
}

variable "ipv4_gw" {
  type    = string
  default = ""
}

variable "nameserver" {
  type    = string
  default = "10.91.1.1"
}

variable "ipv6_addr" {
  type = object({
    addr = string
    mask = string
  })
  default = {
    addr = "dhcp"
    mask = ""
  }
}

variable "ipv6_gw" {
  type    = string
  default = ""
}

variable "proxmox_node" {
  type = string
}

variable "vm_hostname" {
  type = string
}

variable "vm_memory_mb" {
  type    = number
  default = 1024
}

variable "vm_disksize" {
  type    = string
  default = "5G"
}

variable "vm_tags" {
  type = list(string)
}

variable "vm_os" {
  type = string
}

variable "ansible_groups" {
  type    = list(string)
  default = []
}

variable "k3s_version" {
  type = string
  default = "v1.29.0+k3s1"
}