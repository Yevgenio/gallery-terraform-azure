terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
  required_version = ">= 1.6"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gallery" {
  name     = var.resource_group
  location = var.location
}
