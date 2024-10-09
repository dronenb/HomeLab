data "bitwarden_item_login" "cert_manager_cloudflare_token" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "53b1c9f1-80fc-4a17-8127-b0ef01109c56"
}

resource "google_secret_manager_secret" "email" {
  project   = var.homelab_project_id
  secret_id = "email"
  replication {
    auto {}
  }
}

data "google_client_openid_userinfo" "me" {}

resource "google_secret_manager_secret_version" "email" {
  secret      = google_secret_manager_secret.email.id
  secret_data = data.google_client_openid_userinfo.me.email
}

resource "google_secret_manager_secret" "cert_manager_cloudflare_token" {
  project   = var.homelab_project_id
  secret_id = "cert-manager-cloudflare-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "cert_manager_cloudflare_token" {
  secret      = google_secret_manager_secret.cert_manager_cloudflare_token.id
  secret_data = data.bitwarden_item_login.cert_manager_cloudflare_token.password
}

