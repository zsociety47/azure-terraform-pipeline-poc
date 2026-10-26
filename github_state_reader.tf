# Lets the GitHub Actions service principal read the state
# group during terraform plan. Plan refreshes every resource
# in state, including this group. Reader cannot change it.
# Contributor stays on the pipeline group only.

resource "azurerm_role_assignment" "github_state_reader" {
  scope                = azurerm_resource_group.state.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github.object_id
}
