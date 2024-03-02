terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/k3s/state"
  }
}
