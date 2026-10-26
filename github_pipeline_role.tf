# Lets the GitHub Actions service principal change resources
# inside the pipeline group. Contributor can create, update, and
# delete in that group. It cannot create other resource groups,
# because the scope is this group, not the subscription.
# The group file has to exist first. The workflow files need this
# assignment before they can apply.

resource "azurerm_role_assignment" "github_pipeline_contributor" {
  scope                = azurerm_resource_group.pipeline.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github.object_id
}
