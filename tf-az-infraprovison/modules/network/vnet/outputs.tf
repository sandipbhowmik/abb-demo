output "vnet_id" { value = azurerm_virtual_network.vnet.id }
output "aks_subnet_id" { value = azurerm_subnet.aks.id }
output "mysql_subnet_id" { value = azurerm_subnet.mysql.id }
output "app_subnet_id" { value = azurerm_subnet.app.id }