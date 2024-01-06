terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "terraform/gcp/state"
  }
}
