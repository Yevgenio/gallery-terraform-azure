variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "aks_subnet_id" {
  type = string
}

variable "admin_ssh_cidr" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
