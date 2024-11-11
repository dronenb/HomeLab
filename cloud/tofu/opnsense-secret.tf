data "bitwarden_item_login" "opnsense_creds" {
  #checkov:skip=CKV_SECRET_6:This is pulling the secret from Bitwarden
  id = "6f3c6b99-436a-4f18-9359-b225013f9b99"
}

resource "google_secret_manager_secret" "opnsense_key" {
  project   = var.homelab_project_id
  secret_id = "opnsense-key"
  replication {
    auto {}
  }
}


resource "google_secret_manager_secret" "opnsense_secret" {
  project   = var.homelab_project_id
  secret_id = "opnsense-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "opnsense_key" {
  secret      = google_secret_manager_secret.opnsense_key.id
  secret_data = data.bitwarden_item_login.opnsense_creds.field[index(data.bitwarden_item_login.opnsense_creds.field.*.name, "key")].text
}

resource "google_secret_manager_secret_version" "opnsense_secret" {
  secret      = google_secret_manager_secret.opnsense_secret.id
  secret_data = data.bitwarden_item_login.opnsense_creds.field[index(data.bitwarden_item_login.opnsense_creds.field.*.name, "secret")].hidden
}
