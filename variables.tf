variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "rg_name" {
  description = "Resource group name"
  type        = string
  default     = "webapp-rg"
}

variable "vnet_cidr" {
  description = "VNet CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "Your SSH public key (ssh-rsa ...)"
  type        = string
}
