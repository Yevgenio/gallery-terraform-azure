output "appgw_public_ip" {
  value       = module.ingress.appgw_public_ip
  description = "Point gitlab.boukingolts.art and registry.boukingolts.art DNS A records here"
}


output "gitlab_private_ip" {
  value       = module.vms.gitlab_private_ip
  description = "GitLab VM private IP (reachable via Bastion or from within VNet)"
}

output "vault_private_ip" {
  value       = module.vms.vault_private_ip
  description = "Vault VM private IP (AKS pods reach it on port 8200)"
}

output "aks_get_credentials" {
  value       = "az aks get-credentials --resource-group ${var.resource_group} --name gallery-aks"
  description = "Configure kubectl (authorized IP ranges apply — run from an allowed CIDR)"
}

output "nfs_mount_path" {
  value       = module.storage.nfs_mount_path
  description = "NFS mount path — use in Kubernetes PersistentVolume or StorageClass parameters"
}

output "internal_dns_zone" {
  value       = module.network.internal_dns_zone
  description = "Private DNS zone — gitlab.internal.gallery.local and vault.internal.gallery.local"
}

output "gitlab_public_ip" {
  value       = module.vms.gitlab_public_ip
  description = "Temporary GitLab public IP — non-null only when enable_gitlab_public_ip = true"
}
