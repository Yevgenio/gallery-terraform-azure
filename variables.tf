variable "location" {
  default = "westeurope"
}

variable "resource_group" {
  default = "gallery-rg"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "admin_ssh_cidr" {
  description = "Your public IP for SSH allowlisting, e.g. 1.2.3.4/32"
  type        = string
}
