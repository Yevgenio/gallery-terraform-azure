variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_gitlab_public_ip" {
  type    = bool
  default = false
}

variable "admin_ssh_cidr" {
  type = string
}
