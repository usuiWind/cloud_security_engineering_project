# GitHub Actions federation into Entra, pinned to main. A pull_request token has a
# different subject and gets AADSTS700213 (no matching federated identity record).

resource "azuread_application" "github" {
  display_name = "meridian-github-deploy"
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
}

resource "azuread_application_federated_identity_credential" "main" {
  application_id = azuread_application.github.id
  display_name   = "github-main"
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"
  audiences      = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_definition" "deploy" {
  name        = "meridian-deploy"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Pipeline deploy: storage, key vault, network, monitoring only"

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/*",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Storage/*",
      "Microsoft.KeyVault/*",
      "Microsoft.Network/*",
      "Microsoft.Insights/*",
      "Microsoft.OperationalInsights/*",
    ]
  }

  assignable_scopes = ["/subscriptions/${var.subscription_id}"]
}

resource "azurerm_role_assignment" "github_deploy" {
  scope              = "/subscriptions/${var.subscription_id}"
  role_definition_id = azurerm_role_definition.deploy.role_definition_resource_id
  principal_id       = azuread_service_principal.github.object_id
}

resource "azurerm_role_assignment" "github_policy" {
  scope                = azurerm_management_group.meridian.id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = azuread_service_principal.github.object_id
}
