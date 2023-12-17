provider "google" {
  user_project_override = true
  billing_project       = var.homelab_project_id
}

# Homelab project
resource "google_project" "ben_homelab" {
  name                = "Ben-HomeLab"
  project_id          = var.homelab_project_id
  org_id              = var.google_org_id
  billing_account     = var.billing_account_id
  skip_delete         = true
  auto_create_network = false
}

resource "google_project_iam_audit_config" "homelab" {
  project = google_project.ben_homelab.project_id
  service = "allServices"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Enable resource manager API
resource "google_project_service" "homelab_resourcemanager" {
  project            = google_project.ben_homelab.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

# Enable budget API
resource "google_project_service" "homelab_budget" {
  project            = google_project.ben_homelab.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

# Enable pubsub
resource "google_project_service" "homelab_pubsub" {
  project            = google_project.ben_homelab.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}


# Enable Secret Manager API
resource "google_project_service" "homelab_secretmanager" {
  project            = google_project.ben_homelab.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Storage API
resource "google_project_service" "homelab_storage" {
  project            = google_project.ben_homelab.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Bucket for storing state files
resource "google_storage_bucket" "homelab_state" {
  #checkov:skip=CKV_GCP_62:I will setup bucket logging later
  project       = google_project.ben_homelab.project_id
  name          = "homelab-state"
  location      = "US-CENTRAL1"
  force_destroy = false
  autoclass {
    enabled = true
  }
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
