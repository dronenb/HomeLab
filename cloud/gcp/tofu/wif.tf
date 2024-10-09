resource "google_storage_bucket" "k3s_homelab_wif_oidc" {
  #checkov:skip=CKV_GCP_78:Versioning is Handleed by GitHub
  #checkov:skip=CKV_GCP_62:Access logs are not required.
  #checkov:skip=CKV_GCP_114:This Bucket Needs to be Public
  name          = "dronenb-k3s-homelab-wif-oidc"
  location      = "US"
  project       = google_project.ben_homelab.project_id
  force_destroy = true

  public_access_prevention    = "inherited"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "k3s_homelab_wif_oidc_public" {
  #checkov:skip=CKV_GCP_28:This Bucket Needs to be Public
  bucket = google_storage_bucket.k3s_homelab_wif_oidc.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket_object" "k3s-openid-configuration" {
  name   = ".well-known/openid-configuration"
  source = "k3s-wif/.well-known/openid-configuration"
  bucket = google_storage_bucket.k3s_homelab_wif_oidc.name
  cache_control = "max-age=60"
}

resource "google_storage_bucket_object" "k3s-keys-json" {
  name   = "keys.json"
  source = "k3s-wif/keys.json"
  bucket = google_storage_bucket.k3s_homelab_wif_oidc.name
  cache_control = "max-age=60"
}

resource "google_iam_workload_identity_pool" "k3s_homelab_wif" {
  workload_identity_pool_id = "k3s-homelab-wif"
  display_name              = "k3s-homelab-wif"
  description               = "Created By TF"
  project                   = google_project.ben_homelab.project_id
}

resource "google_iam_workload_identity_pool_provider" "k3s_homelab_wif" {
  #checkov:skip=CKV_GCP_118:Allow any identity to authenticate
  display_name                       = "k3s-homelab-wif"
  project                            = google_project.ben_homelab.project_id
  description                        = "Created By TF"
  workload_identity_pool_id          = google_iam_workload_identity_pool.k3s_homelab_wif.workload_identity_pool_id
  workload_identity_pool_provider_id = "k3s-homelab-wif"
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  oidc {
    issuer_uri        = "https://storage.googleapis.com/${google_storage_bucket.k3s_homelab_wif_oidc.name}"
    allowed_audiences = [
      "https://iam.googleapis.com/projects/805422933562/locations/global/workloadIdentityPools/k3s-homelab-wif/providers/k3s-homelab-wif",
      "//iam.googleapis.com/projects/805422933562/locations/global/workloadIdentityPools/k3s-homelab-wif/providers/k3s-homelab-wif",
      "k3s"
    ]
  }
}
