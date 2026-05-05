output "gitlab_private_ip" {
  value = "10.2.1.10"
}

output "vault_private_ip" {
  value = "10.2.1.20"
}

output "gitlab_identity_principal_id" {
  value = azurerm_virtual_machine.gitlab.identity[0].principal_id
}

output "vault_identity_principal_id" {
  value = azurerm_linux_virtual_machine.vault.identity[0].principal_id
}
