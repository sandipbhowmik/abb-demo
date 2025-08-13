resource "azurerm_mysql_flexible_server" "mysql" {
  name                = "${var.name_prefix}-mysql"
  resource_group_name = var.rg_name
  location            = var.location
  sku_name            = "B_Standard_B2s"

  storage {
    size_gb = 32
  }
  version = "8.0.21"

  #high_availability     = "Disabled"
  backup_retention_days  = 7
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
  delegated_subnet_id    = var.subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  tags                   = var.tags
}
