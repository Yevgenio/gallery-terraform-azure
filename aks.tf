resource "azurerm_kubernetes_cluster" "gallery" {
  name                = "gallery-aks"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  dns_prefix          = "gallery"
  kubernetes_version  = "1.30"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2s_v3"  # 2 vCPU / 8 GB per node
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }
}

# Azure Files CSI driver (pre-installed on AKS) needs Contributor on the RG
# to create storage accounts for dynamic PVC provisioning
resource "azurerm_role_assignment" "aks_contributor" {
  principal_id         = azurerm_kubernetes_cluster.gallery.kubelet_identity[0].object_id
  role_definition_name = "Contributor"
  scope                = azurerm_resource_group.gallery.id
}
