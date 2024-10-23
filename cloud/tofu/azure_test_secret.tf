data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "homelab" {
  name     = "homelab"
  location = "North Central US"
}

resource "azurerm_key_vault" "homelab" {
  name                        = "dronenb-homelab"
  location                    = azurerm_resource_group.homelab.location
  resource_group_name         = azurerm_resource_group.homelab.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
}

resource "azurerm_key_vault_access_policy" "homelab" {
  key_vault_id = azurerm_key_vault.homelab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
    "Set",
  ]
}

resource "azurerm_key_vault_secret" "example" {
  name         = "secret-sauce"
  value        = "azure-fake-secret"
  key_vault_id = azurerm_key_vault.homelab.id
}

# Create an application
resource "azuread_application" "homelab_secret_accessor" {
  display_name = "homelab-secret-accessor"
  owners       = [data.azuread_client_config.current.object_id]
  api {
    requested_access_token_version = 2
  }
  # required_resource_access {
  #   # Microsoft Graph API
  #   resource_app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
  # }
}

# Create a service principal
resource "azuread_service_principal" "homelab_secret_accessor" {
  client_id = azuread_application.homelab_secret_accessor.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Create federated credential
resource "azuread_application_federated_identity_credential" "kubecon_demo" {
  application_id = azuread_application.homelab_secret_accessor.id
  display_name   = "default_ns"
  description    = "Binds default sa from default ns"
  audiences      = ["api://AzureADTokenExchange"]
  subject        = "system:serviceaccount:default:default"
  issuer         = "https://storage.googleapis.com/dronenb-k3s-homelab-wif-oidc"
}

# Give SP access to the key vault
resource "azurerm_key_vault_access_policy" "k3s" {
  key_vault_id = azurerm_key_vault.homelab.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.homelab_secret_accessor.object_id

  secret_permissions = [
    "Get",
  ]
}
