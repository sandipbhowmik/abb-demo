resource "azurerm_container_registry" "acr" {
  name                = replace("${var.name_prefix}acr", "-", "")
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
