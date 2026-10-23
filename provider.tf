# Signs in to Azure before any resource file runs.
# Later resource files use these providers. They do not sign in themselves.
#
# Authentication uses the Azure command-line interface (CLI) login already
# on this machine. The subscription id is read from the ARM_SUBSCRIPTION_ID
# environment variable, so it is not stored in this file. ARM is the prefix
# the Azure Resource Manager provider uses for its environment variables.
# The Entra provider reads the tenant from that same CLI login.

provider "azurerm" {
  # Do not register Azure resource providers during apply.
  # Microsoft.Storage and Microsoft.Resources are already registered
  # on this subscription. This project uses them for the state account
  # and the resource group.
  resource_provider_registrations = "none"

  # The state account has shared keys off. Storage data actions,
  # such as creating the container, sign in with Azure AD.
  storage_use_azuread = true

  # Required by the provider even when no feature flags are set.
  features {}
}

provider "azuread" {
}
