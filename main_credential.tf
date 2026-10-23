# Trusts a GitHub Actions token from a push to the main branch.
# The subject is the same repository as the pull-request credential,
# with the branch ref instead of pull_request. Only this subject
# will be allowed to apply.

resource "azuread_application_federated_identity_credential" "main" {
  application_id = azuread_application_registration.github.id
  display_name   = var.main_credential_name
  description    = "The main branch can apply. Pull requests cannot."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = var.main_subject
}
