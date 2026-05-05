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
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 2
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

  # ── Backend pools ──────────────────────────────────────────────────────────

  backend_address_pool {
    name         = "gitlab"
    ip_addresses = [var.gitlab_private_ip]
  }

  # Populate aks_internal_lb_ip variable after the AKS internal LoadBalancer
  # Service is created, or enable AGIC to manage routing from Ingress objects.
  backend_address_pool {
    name         = "aks"
    ip_addresses = var.aks_internal_lb_ip != "" ? [var.aks_internal_lb_ip] : []
  }

  # ── Backend HTTP settings ──────────────────────────────────────────────────

  backend_http_settings {
    name                  = "gitlab-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  backend_http_settings {
    name                  = "registry-http"
    cookie_based_affinity = "Disabled"
    port                  = 5050
    protocol              = "Http"
    request_timeout       = 60
  }

  # Plain HTTP to Traefik port 80 (web entrypoint). App Gateway terminates TLS.
  backend_http_settings {
    name                                = "aks-http"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    probe_name                          = "aks-probe"
  }

  # Traefik returns 404 on root path (no route matched) — treat as healthy.
  probe {
    name                = "aks-probe"
    protocol            = "Http"
    path                = "/"
    host                = "10.2.2.100"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200-404"]
    }
  }

  # ── SSL certificate ────────────────────────────────────────────────────────

  ssl_certificate {
    name     = "gallery-cert"
    data     = filebase64(var.ssl_cert_path)
    password = var.ssl_cert_password
  }

  # ── HTTP listener — catch-all redirect to HTTPS ────────────────────────────
  # target_listener_name only determines scheme+port for the 301 Location header;
  # the original Host is always preserved, so one rule covers all hostnames.

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https-gitlab"
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

  # ── HTTPS listeners ────────────────────────────────────────────────────────

  http_listener {
    name                           = "https-gitlab"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
    host_names                     = [var.gitlab_hostname]
  }

  http_listener {
    name                           = "https-registry"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
    host_names                     = [var.registry_hostname]
  }

  http_listener {
    name                           = "https-argocd"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
    host_names                     = [var.argocd_hostname]
  }

  http_listener {
    name                           = "https-gallery"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
    host_names                     = [var.gallery_hostname]
  }

  http_listener {
    name                           = "https-grafana"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "gallery-cert"
    host_names                     = [var.grafana_hostname]
  }

  # ── HTTPS routing rules ────────────────────────────────────────────────────

  request_routing_rule {
    name                       = "https-gitlab"
    rule_type                  = "Basic"
    priority                   = 20
    http_listener_name         = "https-gitlab"
    backend_address_pool_name  = "gitlab"
    backend_http_settings_name = "gitlab-http"
  }

  request_routing_rule {
    name                       = "https-registry"
    rule_type                  = "Basic"
    priority                   = 25
    http_listener_name         = "https-registry"
    backend_address_pool_name  = "gitlab"
    backend_http_settings_name = "registry-http"
  }

  request_routing_rule {
    name                       = "https-argocd"
    rule_type                  = "Basic"
    priority                   = 30
    http_listener_name         = "https-argocd"
    backend_address_pool_name  = "aks"
    backend_http_settings_name = "aks-http"
  }

  request_routing_rule {
    name                       = "https-gallery"
    rule_type                  = "Basic"
    priority                   = 40
    http_listener_name         = "https-gallery"
    backend_address_pool_name  = "aks"
    backend_http_settings_name = "aks-http"
  }

  request_routing_rule {
    name                       = "https-grafana"
    rule_type                  = "Basic"
    priority                   = 50
    http_listener_name         = "https-grafana"
    backend_address_pool_name  = "aks"
    backend_http_settings_name = "aks-http"
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
