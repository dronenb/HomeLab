terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/gcp/state"
  }
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.93.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "3.2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.25.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.13.5"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.28.0"
    }
    netbox = {
      source  = "e-breuninger/netbox"
      version = "3.10.0"
    }
  }
}
