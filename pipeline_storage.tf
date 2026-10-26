# The resource the pipeline is allowed to create. It lives in
# rg-tfpipe-poc-zeon01. Contributor on that group can create this
# account. It cannot create resource groups.
#
# st is storage. tfpipe is this project. poc is proof of concept.
# zeon01 is the owner. This is not the state account.

resource "azurerm_storage_account" "pipeline" {
  name                     = var.pipeline_storage_account_name
  resource_group_name      = azurerm_resource_group.pipeline.name
  location                 = azurerm_resource_group.pipeline.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  local_user_enabled              = false

  tags = local.pipeline_tags

  lifecycle {
    ignore_changes = [tags["created"]]
  }
}
