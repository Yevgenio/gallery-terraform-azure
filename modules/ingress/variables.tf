variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "appgw_subnet_id" {
  type = string
}

variable "bastion_subnet_id" {
  type = string
}

variable "gitlab_private_ip" {
  type    = string
  default = "10.2.1.10"
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
