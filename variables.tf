variable "resource_group_name" {
  type    = string
  default = "vm-web-rg"
}

variable "location" {
  type    = string
  default = "East US"
}

variable "vm_name" {
  type    = string
  default = "web-vm"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_password" {
  type    = string
}

variable "subscription_id" { type = string }
variable "tenant_id"       { type = string }
variable "client_id"       { type = string }
variable "client_secret"   { type = string }
