terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/k3s_coreos/state"
  }
}
