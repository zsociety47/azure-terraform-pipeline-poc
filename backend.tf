# Tells Terraform to keep its memory in Azure, not only on this laptop.
# The runner cannot see a local terraform.tfstate file. This block
# points at the account, container, and blob already created.
#
# Backend settings cannot use variables. The names are written here
# as the same literals that variables.tf already holds.
#
# Shared keys are off, so sign-in is Azure AD. The subscription id,
# tenant id, and client id stay in the environment. This laptop uses
# the Azure CLI login. A later GitHub job sets ARM_USE_OIDC=true.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfpipe-state-zeon01"
    storage_account_name = "sttfpipezeon01"
    container_name       = "tfstate"
    key                  = "pipeline.tfstate"
    use_azuread_auth     = true
  }
}
