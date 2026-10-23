# The identity Azure checks when this application is assigned a role.
# The app registration is the definition. This principal is the object
# a role assignment can point at. client_id comes from the registration,
# so Terraform creates the application first.

resource "azuread_service_principal" "github" {
  client_id   = azuread_application_registration.github.client_id
  description = "Service principal for the GitHub Actions pipeline."

  account_enabled              = true
  app_role_assignment_required = false
}
