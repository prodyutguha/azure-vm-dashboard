########################################################
# VARIABLES
########################################################
variable "rg_name" {
  default = "myResourceGroup"
}

variable "location" {
  default = "West Europe"
}

variable "vm_size" {
  default = "Standard_B1s"
}

variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  default = "P@ssw0rd1234!" # Use Key Vault or GitHub secrets for production
}

variable "subscription_id" {
  description = "Azure Subscription ID"
}