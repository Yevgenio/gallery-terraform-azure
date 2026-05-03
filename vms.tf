locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
}

# ── GitLab VM ────────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "gitlab" {
  name                = "gitlab-pip"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "gitlab" {
  name                = "gitlab-nic"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.infra.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.10"
    public_ip_address_id          = azurerm_public_ip.gitlab.id
  }
}

resource "azurerm_network_interface_security_group_association" "gitlab" {
  network_interface_id      = azurerm_network_interface.gitlab.id
  network_security_group_id = azurerm_network_security_group.gitlab.id
}

resource "azurerm_linux_virtual_machine" "gitlab" {
  name                = "gitlab-vm"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  size                = "Standard_B4ms"   # 4 vCPU / 16 GB — minimum for GitLab CE + registry
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.gitlab.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 100
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ── Vault VM ─────────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "vault" {
  name                = "vault-pip"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vault" {
  name                = "vault-nic"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.infra.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.20"
    public_ip_address_id          = azurerm_public_ip.vault.id
  }
}

resource "azurerm_network_interface_security_group_association" "vault" {
  network_interface_id      = azurerm_network_interface.vault.id
  network_security_group_id = azurerm_network_security_group.vault.id
}

resource "azurerm_linux_virtual_machine" "vault" {
  name                = "vault-vm"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  size                = "Standard_B2s"    # 2 vCPU / 4 GB — Vault is lightweight
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.vault.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = local.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
