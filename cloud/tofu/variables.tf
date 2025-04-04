variable "homelab_project_id" {
  type      = string
  sensitive = true
}
variable "user_email" {
  type      = string
  sensitive = true
}
variable "billing_account_id" {
  type      = string
  sensitive = true
}
variable "google_org_id" {
  type      = number
  sensitive = true
}
variable "azure_subscription_id" {
  type      = string
  sensitive = true
}