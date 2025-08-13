data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "uami" {
  name                = "${var.name_prefix}-wi"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
}

resource "azurerm_federated_identity_credential" "fic" {
  name                = "${var.name_prefix}-fic"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.uami.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}
