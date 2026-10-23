# Pins the tool versions before any Azure resource is declared.
# terraform init reads this block and downloads the providers it names.
# Later resource files depend on those providers staying the same version.
#
# azurerm manages the state storage account and the resource group the pipeline applies.
# azuread manages the app registration GitHub Actions uses to sign in.

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.10.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0"
    }
  }
}
