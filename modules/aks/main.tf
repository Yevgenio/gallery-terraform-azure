resource "azurerm_kubernetes_cluster" "gallery" {
  name                = "gallery-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "gallery"
  kubernetes_version  = "1.35"

  api_server_access_profile {
    authorized_ip_ranges = [
      var.admin_ssh_cidr,
      "10.2.1.0/24",          # infra subnet — GitLab runner, Vault, ops tooling
      "10.2.0.0/24",          # appgw subnet — Application Gateway health probes
      var.nat_gateway_pip     # NAT Gateway public IP — nodes egress via this to reach the API server
    ]
  }

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_D2s_v3"  # 2 vCPU / 4 GB per node
    vnet_subnet_id       = var.aks_subnet_id
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 4
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    outbound_type     = "userAssignedNATGateway"
  }

  tags = var.tags
}

# The AKS node resource group (MC_...) is created automatically by Azure.
# Azure Files CSI driver creates storage accounts there for dynamic PVC provisioning.
data "azurerm_resource_group" "aks_nodes" {
  name       = "MC_${var.resource_group_name}_gallery-aks_${var.location}"
  depends_on = [azurerm_kubernetes_cluster.gallery]
}

resource "azurerm_role_assignment" "aks_storage" {
  principal_id         = azurerm_kubernetes_cluster.gallery.kubelet_identity[0].object_id
  role_definition_name = "Storage Account Contributor"
  scope                = data.azurerm_resource_group.aks_nodes.id
}

resource "azurerm_role_assignment" "aks_vnet" {
  principal_id         = azurerm_kubernetes_cluster.gallery.identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = var.resource_group_id
}
