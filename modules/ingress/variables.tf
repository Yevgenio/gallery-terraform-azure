variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "appgw_subnet_id" {
  type = string
}


variable "gitlab_private_ip" {
  type    = string
  default = "10.2.1.10"
}

variable "aks_internal_lb_ip" {
  type        = string
  default     = ""
  description = "AKS internal LoadBalancer IP — set after first apply once the AKS Service is created"
}

variable "gitlab_hostname" {
  type    = string
  default = "gitlab.boukingolts.art"
}

variable "argocd_hostname" {
  type    = string
  default = "argocd.boukingolts.art"
}

variable "gallery_hostname" {
  type    = string
  default = "boukingolts.art"
}

variable "grafana_hostname" {
  type    = string
  default = "grafana.boukingolts.art"
}

variable "ssl_cert_path" {
  type = string
}

variable "ssl_cert_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
