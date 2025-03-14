variable "root_password" {
  type      = string
  sensitive = true
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

variable "search_domains" {
  type    = list(string)
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

variable "vm_disksize_gb" {
  type    = number
  default = 10
}

variable "vm_tags" {
  type = list(string)
}

variable "vm_os" {
  type = string
}
