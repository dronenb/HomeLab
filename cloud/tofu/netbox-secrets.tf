data "bitwarden_item_login" "netbox_creds" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "e8c3d331-3b79-4986-8977-b2a3001b1842"
}

resource "google_secret_manager_secret" "netbox_user" {
  project   = var.homelab_project_id
  secret_id = "netbox-user"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netbox_password" {
  project   = var.homelab_project_id
  secret_id = "netbox-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "netbox_api_token" {
  project   = var.homelab_project_id
  secret_id = "netbox-api-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "netbox_user" {
  secret      = google_secret_manager_secret.netbox_user.id
  secret_data = data.bitwarden_item_login.netbox_creds.username
}

resource "google_secret_manager_secret_version" "netbox_password" {
  secret      = google_secret_manager_secret.netbox_password.id
  secret_data = data.bitwarden_item_login.netbox_creds.password
}

resource "google_secret_manager_secret_version" "netbox_api_token" {
  secret      = google_secret_manager_secret.netbox_api_token.id
  secret_data = data.bitwarden_item_login.netbox_creds.field[index(data.bitwarden_item_login.netbox_creds.field.*.name, "api_token")].hidden
}
