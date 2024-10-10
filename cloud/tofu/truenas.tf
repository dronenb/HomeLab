
# Bucket for backing up TrueNAS
resource "google_storage_bucket" "fh_truenas0_backup" {
  #checkov:skip=CKV_GCP_62:I will setup bucket logging later
  project       = google_project.ben_homelab.project_id
  name          = "fh-truenas0-backup"
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
