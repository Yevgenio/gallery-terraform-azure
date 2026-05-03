output "appgw_public_ip" {
  value = azurerm_public_ip.appgw.ip_address
}

output "bastion_fqdn" {
  value = azurerm_bastion_host.main.dns_name
}
