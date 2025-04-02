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

resource "netbox_rir" "rfc1918" {
  name        = "rfc1918"
  description = "RFC 1918 Private Address Space - https://datatracker.ietf.org/doc/html/rfc1918"
  is_private  = true
}

resource "netbox_rir" "rfc3927" {
  name        = "rfc3927"
  description = "RFC 3927 Private Address Space - https://datatracker.ietf.org/doc/html/rfc3927"
  is_private  = true
}

resource "netbox_rir" "rfc4193" {
  name        = "rfc4193"
  description = "RFC 4193 local IPv6 unicast address space - https://datatracker.ietf.org/doc/html/rfc4193"
  is_private  = true
}

resource "netbox_rir" "rfc6598" {
  name        = "rfc6598"
  description = "RFC 6598 CGNAT Address Space - https://datatracker.ietf.org/doc/html/rfc6598"
  is_private  = true
}

resource "netbox_aggregate" "rfc_1918_10_0_0_0_8" {
  prefix      = "10.0.0.0/8"
  description = "10/8 RFC 1918 Private Address Space"
  rir_id      = netbox_rir.rfc1918.id
}

resource "netbox_aggregate" "rfc_1918_192_168_0_0_16" {
  prefix      = "192.168.0.0/16"
  description = "192.168/16 RFC 1918 Private Address Space"
  rir_id      = netbox_rir.rfc1918.id
}

resource "netbox_aggregate" "rfc_1918_172_16_0_0_12" {
  prefix      = "172.16.0.0/12"
  description = "172.16/12 RFC 1918 Private Address Space"
  rir_id      = netbox_rir.rfc1918.id
}

resource "netbox_aggregate" "rfc_3927" {
  prefix      = "169.254.0.0/16"
  description = "169.254/16 RFC 3927 Private Address Space"
  rir_id      = netbox_rir.rfc3927.id
}

resource "netbox_aggregate" "rfc_6598" {
  prefix      = "100.64.0.0/10"
  description = "100.64.0.0/10 RFC 6598 CGNAT Address Space"
  rir_id      = netbox_rir.rfc6598.id
}

resource "netbox_aggregate" "rfc_4193" {
  prefix      = "fc00::/7"
  description = "fc00::/7 RFC 4193 local IPv6 unicast addresses"
  rir_id      = netbox_rir.rfc4193.id
}
