variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name (3-24 chars, lowercase alphanumeric)"
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "aks_subnet_id" {
  type        = string
  description = "AKS subnet ID — storage account network rules restrict access to this subnet"
}

variable "tags" {
  type    = map(string)
  default = {}
}
