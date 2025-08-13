data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                          = replace("${var.name_prefix}-kv", "-", "")
  location                      = var.location
  resource_group_name           = var.rg_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  enable_rbac_authorization     = true
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_role_assignment" "tf_can_manage_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.tf_operator_object_id
  depends_on           = [azurerm_key_vault.kv]
}
