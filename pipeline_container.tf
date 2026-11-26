# A private blob container in the pipeline storage account.
# The pull-request job plans this. It does not apply. Merge to
# main is what would create it. Contributor on rg-tfpipe-poc-zeon01
# can add this container. It cannot add a resource group.
#
# walkthrough is the role. The account name already carries the
# project and owner. This is not the tfstate container.

resource "azurerm_storage_container" "walkthrough" {
  name                  = var.pipeline_container_name
  storage_account_id    = azurerm_storage_account.pipeline.id
  container_access_type = "private"
}
