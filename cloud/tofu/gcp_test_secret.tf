resource "google_secret_manager_secret" "test_secret" {
  project   = var.homelab_project_id
  secret_id = "test-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "test_secret" {
  secret      = google_secret_manager_secret.test_secret.id
  secret_data = "gcp-fake-secret"
}

resource "google_secret_manager_secret_iam_member" "member" {
  project   = google_secret_manager_secret.test_secret.project
  secret_id = google_secret_manager_secret.test_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "principal://iam.googleapis.com/projects/${google_project.ben_homelab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k3s_homelab_wif.workload_identity_pool_id}/subject/system:serviceaccount:secrets-store-csi-driver:secrets-store-csi-driver-provider-gcp"
}

resource "google_secret_manager_secret_iam_member" "member2" {
  project   = google_secret_manager_secret.test_secret.project
  secret_id = google_secret_manager_secret.test_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "principal://iam.googleapis.com/projects/${google_project.ben_homelab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k3s_homelab_wif.workload_identity_pool_id}/subject/system:serviceaccount:default:default"
}