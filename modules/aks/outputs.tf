output "cluster_id" {
  value = azurerm_kubernetes_cluster.gallery.id
}

output "identity_principal_id" {
  value = azurerm_kubernetes_cluster.gallery.identity[0].principal_id
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.gallery.kubelet_identity[0].object_id
}

output "cluster_identity_principal_id" {
  value = azurerm_kubernetes_cluster.gallery.identity[0].principal_id
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.gallery.kube_config_raw
  sensitive = true
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.gallery.fqdn
}
