# The Entra application GitHub Actions will use to sign in.
# There is no client secret. A later file attaches a federated
# credential, which trusts GitHub's OpenID Connect token instead.
# AzureADMyOrg means only this tenant can use the application.

resource "azuread_application_registration" "github" {
  display_name     = var.application_display_name
  description      = "GitHub Actions signs in with OpenID Connect. No client secret."
  sign_in_audience = "AzureADMyOrg"
}
