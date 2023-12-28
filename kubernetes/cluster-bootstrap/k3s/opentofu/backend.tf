terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "opentofu/k3s/state"
  }
}
