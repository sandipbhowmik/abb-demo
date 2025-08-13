resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

# Shared resources
module "log_analytics" {
  source      = "./modules/shared/logAnalytics"
  location    = var.location
  rg_name     = azurerm_resource_group.rg.name
  name_prefix = var.name_prefix
  tags        = var.tags
}

module "app_insights" {
  source      = "./modules/shared/applicationInsights"
  location    = var.location
  rg_name     = azurerm_resource_group.rg.name
  name_prefix = var.name_prefix
  tags        = var.tags
}

module "acr" {
  source      = "./modules/shared/containerRegistry"
  location    = var.location
  rg_name     = azurerm_resource_group.rg.name
  name_prefix = var.name_prefix
  tags        = var.tags
}

# Get the current authenticated principal (user/SP/federated identity)
data "azurerm_client_config" "current" {}

module "keyvault" {
  source                = "./modules/shared/keyvault"
  location              = var.location
  rg_name               = azurerm_resource_group.rg.name
  name_prefix           = var.name_prefix
  tags                  = var.tags
  tf_operator_object_id = data.azurerm_client_config.current.object_id
}

# Networking
module "vnet" {
  source            = "./modules/network/vnet"
  location          = var.location
  rg_name           = azurerm_resource_group.rg.name
  name_prefix       = var.name_prefix
  vnet_cidr         = "10.60.0.0/16"
  aks_subnet_cidr   = "10.60.1.0/24"
  app_subnet_cidr   = "10.60.2.0/24"
  mysql_subnet_cidr = "10.60.3.0/24"
  tags              = var.tags
}

module "mysql_dns_zone" {
  source      = "./modules/network/private-dns-zone"
  location    = var.location
  rg_name     = azurerm_resource_group.rg.name
  name_prefix = var.name_prefix
  zone_name   = "privatelink.mysql.database.azure.com"
  vnet_id     = module.vnet.vnet_id
  tags        = var.tags
}

# AKS
module "aks" {
  source                     = "./modules/containerapps/_replaced-with-aks"
  location                   = var.location
  rg_name                    = azurerm_resource_group.rg.name
  name_prefix                = var.name_prefix
  subnet_id                  = module.vnet.aks_subnet_id
  log_analytics_workspace_id = module.log_analytics.id
  aad_admin_group_object_ids = var.aad_admin_group_object_ids
  tags                       = var.tags
}

# Allow AKS to pull from ACR
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_object_id
}

# MySQL with auto-generated credentials
resource "random_password" "mysql_admin" {
  length  = 10
  special = true
}

resource "azurerm_key_vault_secret" "mysql_admin_login" {
  name         = "mysql-admin-login"
  value        = var.mysql_administrator_login
  key_vault_id = module.keyvault.id
}

resource "azurerm_key_vault_secret" "mysql_admin_password" {
  name         = "mysql-admin-password"
  value        = random_password.mysql_admin.result
  key_vault_id = module.keyvault.id
}

module "mysql" {
  source                 = "./modules/database/mysql"
  location               = var.location
  rg_name                = azurerm_resource_group.rg.name
  name_prefix            = var.name_prefix
  subnet_id              = module.vnet.mysql_subnet_id
  private_dns_zone_id    = module.mysql_dns_zone.id
  administrator_login    = var.mysql_administrator_login
  administrator_password = random_password.mysql_admin.result
  tags                   = var.tags
}

# Workload Identity for Key Vault CSI
module "workload_identity" {
  source              = "./modules/aks/workload-identity"
  name_prefix         = var.name_prefix
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  key_vault_id        = module.keyvault.id
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = "apps"
  service_account     = "petclinic-sa"
}

output "workload_identity_client_id" {
  value = module.workload_identity.uami_client_id
}

# Azure OpenAI (with deployment + RBAC for AKS UAMI)
#module "ai_openai" {
#  source      = "./modules/ai/openai"
#  enable      = true
#  location    = var.location
# rg_name     = azurerm_resource_group.rg.name
#  name_prefix = var.name_prefix
# tags        = var.tags

#  create_deployment = true
#  deployment_name   = "gpt-4o-mini"
#  model_format      = "OpenAI"
#  model_name        = "gpt-4o-mini"
#  model_version     = "latest"
#  sku_name          = "S0"
#  capacity          = 20

  # Grant AKS workload identity access to call Azure OpenAI
#  assign_role_to_principal_id = module.workload_identity.uami_principal_id
#}

