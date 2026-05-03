resource "azurerm_storage_account" "nfs" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = "FileStorage"
  account_tier             = "Premium"
  account_replication_type = "LRS"

  # NFS uses port 2049 — HTTPS-only must be off
  https_traffic_only_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.aks_subnet_id]
  }

  tags = var.tags
}

# Premium NFS shares require a minimum of 100 GiB quota
resource "azurerm_storage_share" "nfs" {
  name               = "gallery-nfs"
  storage_account_id = azurerm_storage_account.nfs.id
  quota              = 100
  enabled_protocol   = "NFS"
}
