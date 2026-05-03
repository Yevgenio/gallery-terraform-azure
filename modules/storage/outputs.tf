output "storage_account_name" {
  value = azurerm_storage_account.nfs.name
}

output "nfs_share_name" {
  value = azurerm_storage_share.nfs.name
}

output "nfs_mount_path" {
  value       = "//${azurerm_storage_account.nfs.primary_file_host}/${azurerm_storage_share.nfs.name}"
  description = "Mount path for use in Kubernetes PersistentVolume or StorageClass"
}
