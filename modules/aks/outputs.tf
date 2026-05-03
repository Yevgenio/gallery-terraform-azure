output "cluster_id" {
  value = azurerm_kubernetes_cluster.gallery.id
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.gallery.kube_config_raw
  sensitive = true
}
