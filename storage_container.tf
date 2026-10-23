# The container that will hold the state blob.
# It takes its account from azurerm_storage_account.state, so the
# account has to exist first. The role assignment is named in
# depends_on because Terraform cannot see that permission from a
# value. The container is private: no anonymous read.

resource "azurerm_storage_container" "state" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.operator_blob_owner]
}
