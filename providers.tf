terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.10.0"
    }

    random = {
      source = "hashicorp/random"
      version = "3.4.3"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0.4"
    }
  }
}