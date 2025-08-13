# Azure OpenAI via AzAPI with optional deployment + RBAC
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0.0"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azapi_resource" "account" {
  count     = var.enable ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts@2023-05-01"
  name      = "${var.name_prefix}-aoai"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.rg_name}"
  # body = jsonencode({
  body = {
    kind = "OpenAI"
    # sku  = { name = "S0" }
    sku = {
      name = var.sku_name
    }
    properties = {
      publicNetworkAccess = "Enabled"
    }
    tags = var.tags
  }
}

# Optional model deployment
resource "azapi_resource" "deployment" {
  count     = var.enable && var.create_deployment ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.deployment_name
  parent_id = azapi_resource.account[0].id
  # body = jsonencode({
  body = {
    sku = {
      name     = var.sku_name
      capacity = var.capacity
    }
    properties = {
      model = {
        format  = var.model_format
        name    = var.model_name
        version = var.model_version
      }
      raiPolicyName        = null
      versionUpgradeOption = "NoAutoUpgrade"
    }
  }
}

# RBAC grant to a principal
resource "azurerm_role_assignment" "openai_user" {
  for_each                         = var.enable ? { "p1" = var.assign_role_to_principal_id } : {}
  scope                            = one(azapi_resource.account[*].id)
  role_definition_name             = "Cognitive Services OpenAI User"
  principal_id                     = each.value
  skip_service_principal_aad_check = true

  depends_on = [azapi_resource.account]
}



