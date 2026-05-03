output "gitlab_public_ip" {
  value       = azurerm_public_ip.gitlab.ip_address
  description = "Point gitlab.boukingolts.art and registry.boukingolts.art here"
}

output "vault_public_ip" {
  value       = azurerm_public_ip.vault.ip_address
  description = "SSH only — Vault API is internal (10.2.1.20:8200)"
}

output "aks_get_credentials" {
  value       = "az aks get-credentials --resource-group ${var.resource_group} --name gallery-aks"
  description = "Run this to configure kubectl"
}
