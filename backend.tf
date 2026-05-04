terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatest3fe"
    container_name       = "tfstate-container"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}
