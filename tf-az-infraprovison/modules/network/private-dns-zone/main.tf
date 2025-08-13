resource "azurerm_private_dns_zone" "dns" {
  name                = var.zone_name
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "${var.name_prefix}-dnslink"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}
