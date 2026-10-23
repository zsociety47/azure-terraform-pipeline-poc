# Lets the GitHub Actions service principal read and write blobs
# in the state account. Shared keys are off, so the pipeline cannot
# open the state file without this role. Data Contributor can change
# blob contents. It cannot change the storage account itself.

resource "azurerm_role_assignment" "github_blob_contributor" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github.object_id
}
