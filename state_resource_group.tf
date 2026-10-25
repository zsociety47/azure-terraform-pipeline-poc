# The container for the remote state storage account.
# The storage account file will reference this block, so Terraform
# creates the group first. The group the pipeline manages is a
# separate file and is not declared here.

resource "azurerm_resource_group" "state" {
  name     = var.state_resource_group_name
  location = var.location
  tags     = local.state_tags

  lifecycle {
    ignore_changes = [tags["created"]]
  }
}
