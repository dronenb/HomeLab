terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/gcp/state"
  }
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.6.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.10.0"
    }
  }
}
