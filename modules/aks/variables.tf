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

variable "nat_gateway_pip" {
  type        = string
  description = "Public IP of the NAT Gateway — added to API server authorized IP ranges so nodes can reach it"
}

variable "tags" {
  type    = map(string)
  default = {}
}
