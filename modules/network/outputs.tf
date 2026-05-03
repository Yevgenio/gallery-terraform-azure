output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "infra_subnet_id" {
  value = azurerm_subnet.infra.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}


output "gitlab_nsg_id" {
  value = azurerm_network_security_group.gitlab.id
}

output "vault_nsg_id" {
  value = azurerm_network_security_group.vault.id
}

output "internal_dns_zone" {
  value = azurerm_private_dns_zone.internal.name
}
