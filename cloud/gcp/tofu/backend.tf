terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/gcp/state"
  }
}
