terraform {
  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.8.0"
    }
  }
}
provider "bitwarden" {}

provider "google" {
  user_project_override = true
  billing_project       = var.homelab_project_id
}
variable "homelab_project_id" {
  type      = string
  sensitive = true
}
