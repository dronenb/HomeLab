terraform {
  backend "gcs" {
    bucket = "homelab-state"
    prefix = "tofu/gcp/state"
  }
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.19.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "3.6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.51.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.16.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "7.9.0"
    }
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.0.0"
    }
  }
}
