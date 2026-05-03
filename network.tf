resource "azurerm_virtual_network" "gallery" {
  name                = "gallery-vnet"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "infra" {
  name                 = "infra-subnet"
  resource_group_name  = azurerm_resource_group.gallery.name
  virtual_network_name = azurerm_virtual_network.gallery.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.gallery.name
  virtual_network_name = azurerm_virtual_network.gallery.name
  address_prefixes     = ["10.2.2.0/24"]
}

# ── GitLab NSG ──────────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "gitlab" {
  name                = "gitlab-nsg"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.admin_ssh_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "Allow-Web"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443", "5050"]
  }
}

resource "azurerm_subnet_network_security_group_association" "gitlab" {
  subnet_id                 = azurerm_subnet.infra.id
  network_security_group_id = azurerm_network_security_group.gitlab.id
}

# ── Vault NSG ───────────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "vault" {
  name                = "vault-nsg"
  location            = azurerm_resource_group.gallery.location
  resource_group_name = azurerm_resource_group.gallery.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.admin_ssh_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "Allow-Vault-from-AKS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.2.2.0/24"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "8200"
  }
}
