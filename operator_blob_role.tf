# Lets the signed-in operator create and read blobs in the state account.
# Shared keys are off, so this role is the only way in.
# The container file needs this assignment, so the role comes first.
#
# The data block reads the current Azure CLI login. It creates nothing.

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "operator_blob_owner" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}
