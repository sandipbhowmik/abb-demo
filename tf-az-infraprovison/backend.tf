terraform {
  backend "azurerm" {
    resource_group_name  = "abb-demo-rg-tfstate"
    storage_account_name = "abbdemotfsa"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
