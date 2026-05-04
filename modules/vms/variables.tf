variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "infra_subnet_id" {
  type = string
}

variable "gitlab_nsg_id" {
  type = string
}

variable "vault_nsg_id" {
  type = string
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  type    = map(string)
  default = {}
}
