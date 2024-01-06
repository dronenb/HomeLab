terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "terraform/cert-manager/state/pre"
  }
}
