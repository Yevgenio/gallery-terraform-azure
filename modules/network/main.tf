# ── VNet ─────────────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "gallery" {
  name                = "gallery-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.2.0.0/16"]
  tags                = var.tags
}

# ── Subnets ───────────────────────────────────────────────────────────────────
resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.gallery.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_subnet" "infra" {
  name                 = "infra-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.gallery.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.gallery.name
  address_prefixes     = ["10.2.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}


# ── NAT Gateway ───────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "nat" {
  name                = "gallery-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "gallery-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "infra" {
  subnet_id      = azurerm_subnet.infra.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ── NSGs ──────────────────────────────────────────────────────────────────────
resource "azurerm_network_security_group" "appgw" {
  name                = "appgw-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Required by Azure for Application Gateway v2 infrastructure probes
  security_rule {
    name                       = "Allow-AppGW-Infra"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "65200-65535"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}


resource "azurerm_network_security_group" "gitlab" {
  name                = "gitlab-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.2.0.0/24"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443"]
  }

  security_rule {
    name                       = "Allow-Registry-from-AKS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.2.2.0/24"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "5050"
  }

  security_rule {
    name                       = "Allow-Bastion-SSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.2.3.0/26"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  dynamic "security_rule" {
    for_each = var.enable_gitlab_public_ip ? [1] : []
    content {
      name                       = "Allow-Temp-Admin-SSH"
      priority                   = 200
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = var.admin_ssh_cidr
      source_port_range          = "*"
      destination_address_prefix = "*"
      destination_port_range     = "22"
    }
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "vault" {
  name                = "vault-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-Bastion-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.2.3.0/26"
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

  tags = var.tags
}

# ── Private DNS ───────────────────────────────────────────────────────────────
resource "azurerm_private_dns_zone" "internal" {
  name                = "internal.gallery.local"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "gallery" {
  name                  = "gallery-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.gallery.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "gitlab" {
  name                = "gitlab"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.2.1.10"]
}

resource "azurerm_private_dns_a_record" "registry" {
  name                = "registry"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.2.1.10"]
}

resource "azurerm_private_dns_a_record" "vault" {
  name                = "vault"
  zone_name           = azurerm_private_dns_zone.internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = ["10.2.1.20"]
}
