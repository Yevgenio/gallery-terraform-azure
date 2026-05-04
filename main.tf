locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "gallery"
  })
}

resource "azurerm_resource_group" "gallery" {
  name     = var.resource_group
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "./modules/network"

  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  tags                = local.common_tags
}

module "vms" {
  source = "./modules/vms"

  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  infra_subnet_id     = module.network.infra_subnet_id
  gitlab_nsg_id       = module.network.gitlab_nsg_id
  vault_nsg_id        = module.network.vault_nsg_id
  ssh_public_key_path = var.ssh_public_key_path
  tags                = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  aks_subnet_id       = module.network.aks_subnet_id
  admin_ssh_cidr      = var.admin_ssh_cidr
  tags                = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  resource_group_name  = azurerm_resource_group.gallery.name
  location             = azurerm_resource_group.gallery.location
  storage_account_name = var.storage_account_name
  aks_subnet_id        = module.network.aks_subnet_id
  tags                 = local.common_tags
}

resource "azurerm_private_dns_cname_record" "aks" {
  name                = "aks"
  zone_name           = module.network.internal_dns_zone
  resource_group_name = azurerm_resource_group.gallery.name
  ttl                 = 300
  record              = module.aks.fqdn
}

module "ingress" {
  source = "./modules/ingress"

  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  appgw_subnet_id     = module.network.appgw_subnet_id
  bastion_subnet_id   = module.network.bastion_subnet_id
  gitlab_private_ip   = module.vms.gitlab_private_ip
  ssl_cert_path       = var.appgw_ssl_cert_path
  ssl_cert_password   = var.appgw_ssl_cert_password
  tags                = local.common_tags
}
