variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for all resources"
}

variable "resource_group" {
  type        = string
  default     = "gallery-rg"
  description = "Name of the main resource group"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment label applied to all resources as a tag"
  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "environment must be one of: production, staging, dev."
  }
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to SSH public key for VM admin access"
}

variable "admin_ssh_cidr" {
  type        = string
  description = "Your public IP CIDR for Bastion NSG allowlisting, e.g. 1.2.3.4/32"
  validation {
    condition     = can(cidrhost(var.admin_ssh_cidr, 0))
    error_message = "admin_ssh_cidr must be a valid CIDR block, e.g. 1.2.3.4/32."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge onto all resources"
}

variable "appgw_ssl_cert_path" {
  type        = string
  description = "Local path to PFX-encoded SSL certificate for Application Gateway"
}

variable "appgw_ssl_cert_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for the PFX SSL certificate"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the NFS storage account (3-24 chars, lowercase alphanumeric)"
}

variable "aks_internal_lb_ip" {
  type        = string
  default     = ""
  description = "AKS internal LoadBalancer IP — set after Traefik ILB is provisioned (pinned to 10.2.2.100)"
}
