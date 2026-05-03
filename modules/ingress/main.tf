# ── Application Gateway ───────────────────────────────────────────────────────
resource "azurerm_public_ip" "appgw" {
  name                = "gallery-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_application_gateway" "main" {
  name                = "gallery-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  backend_address_pool {
    name         = "gitlab"
    ip_addresses = [var.gitlab_private_ip]
  }

  # Populate with AKS internal LB IP once the cluster is running,
  # or enable AGIC to manage this pool from Kubernetes Ingress objects.
  backend_address_pool {
    name = "aks"
  }

  backend_http_settings {
    name                  = "gitlab-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  ssl_certificate {
    name     = "gallery-cert"
    data     = filebase64(var.ssl_cert_path)
    password = var.ssl_cert_password
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https"
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                        = "http-redirect"
    rule_type                   = "Basic"
    priority                    = 10
    http_listener_name          = "http"
    redirect_configuration_name = "http-to-https"
  }

  request_routing_rule {
    name                       = "https-gitlab"
    rule_type                  = "Basic"
    priority                   = 20
    http_listener_name         = "https"
    backend_address_pool_name  = "gitlab"
    backend_http_settings_name = "gitlab-http"
  }

}

# ── Azure Bastion ─────────────────────────────────────────────────────────────
resource "azurerm_public_ip" "bastion" {
  name                = "gallery-bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "gallery-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}
