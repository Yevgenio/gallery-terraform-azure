locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
}

# ── GitLab VM ─────────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "gitlab_temp" {
  count               = var.enable_gitlab_public_ip ? 1 : 0
  name                = "gitlab-temp-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "gitlab" {
  name                = "gitlab-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.infra_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.10"
    public_ip_address_id          = var.enable_gitlab_public_ip ? azurerm_public_ip.gitlab_temp[0].id : null
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "gitlab" {
  network_interface_id      = azurerm_network_interface.gitlab.id
  network_security_group_id = var.gitlab_nsg_id
}

resource "azurerm_linux_virtual_machine" "gitlab" {
  name                  = "gitlab-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2s_v3"  # 2 vCPU / 8 GB
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.gitlab.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ── Vault VM ──────────────────────────────────────────────────────────────────
resource "azurerm_network_interface" "vault" {
  name                = "vault-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.infra_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.20"
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "vault" {
  network_interface_id      = azurerm_network_interface.vault.id
  network_security_group_id = var.vault_nsg_id
}

resource "azurerm_linux_virtual_machine" "vault" {
  name                  = "vault-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_D2as_v4"   # 2 vCPU / 8 GB — smallest Gen 2 available in westeurope
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vault.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
