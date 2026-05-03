output "gitlab_private_ip" {
  value = "10.2.1.10"
}

output "gitlab_public_ip" {
  value       = var.enable_gitlab_public_ip ? azurerm_public_ip.gitlab_temp[0].ip_address : null
  description = "Temporary public IP — null when enable_gitlab_public_ip = false"
}

output "vault_private_ip" {
  value = "10.2.1.20"
}

output "gitlab_identity_principal_id" {
  value = azurerm_linux_virtual_machine.gitlab.identity[0].principal_id
}

output "vault_identity_principal_id" {
  value = azurerm_linux_virtual_machine.vault.identity[0].principal_id
}
