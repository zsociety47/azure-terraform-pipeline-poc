# Empty group the pipeline will be allowed to change.
# A role cannot be scoped to a group that does not exist, and the
# GitHub service principal is not allowed to create resource groups.
# This group is separate from the state group, so removing it does
# not delete the state file.

resource "azurerm_resource_group" "pipeline" {
  name     = var.pipeline_resource_group_name
  location = var.location
  tags     = local.pipeline_tags

  lifecycle {
    ignore_changes = [tags["created"]]
  }
}
