resource "google_dns_managed_zone" "dronen_house" {
  project = var.homelab_project_id
  name        = "dronen-house"
  dns_name    = "dronen.house."
  description = "Public DNS zone for ACME DNS Challenges"
  visibility  = "public"
}

resource "google_project_iam_member" "dns_admin" {
  project = var.homelab_project_id
  role    = "roles/dns.admin"
  member  = "principal://iam.googleapis.com/projects/${google_project.ben_homelab.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.k3s_homelab_wif.workload_identity_pool_id}/subject/system:serviceaccount:cert-manager:cert-manager"
}
