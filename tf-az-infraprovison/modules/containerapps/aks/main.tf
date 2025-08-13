resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.rg_name
  dns_prefix          = "${var.name_prefix}-dns"

  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D2s_v5"
    node_count                   = 1
    vnet_subnet_id               = var.subnet_id
    type                         = "VirtualMachineScaleSets"
    auto_scaling_enabled         = true
    min_count                    = 1
    max_count                    = 2                
    upgrade_settings {
      max_surge = "1"                       # avoid consuming extra surge capacity
    }
    
  }

  identity { type = "SystemAssigned" }

  role_based_access_control_enabled = true
  
  azure_active_directory_role_based_access_control {
    #managed                = true
    admin_group_object_ids = var.aad_admin_group_object_ids
}

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true
  local_account_disabled    = true
  sku_tier                  = "Standard"

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = var.tags
}
