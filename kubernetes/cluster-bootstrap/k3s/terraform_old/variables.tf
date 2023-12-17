variable "cloudinit_username" {
  type = string
}

variable "cloudinit_password" {
  type      = string
  sensitive = true
}
variable "k3s_master_count" {
  type      = number
  sensitive = false
}
variable "k3s_node_count" {
  type      = number
  sensitive = false
}