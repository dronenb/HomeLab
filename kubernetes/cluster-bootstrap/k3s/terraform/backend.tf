terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "terraform/k3s/state"
  }
}
