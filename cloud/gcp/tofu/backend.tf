terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/gcp/state"
  }
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.4.2"
    }
    google = {
      source  = "hashicorp/google"
      version = "5.30.0"
    }
  }
}
