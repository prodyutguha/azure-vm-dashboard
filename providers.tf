terraform {
  backend "azurerm" {
    resource_group_name = "RG-Terraform-Storage-Account"
    storage_account_name = "tfstorage43blrg"
    container_name       = "tfstate"
    key                  = "${var.vm_name}.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}