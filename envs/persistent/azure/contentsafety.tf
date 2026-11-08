# M4 guard layer: Prompt Shields and text analysis, in the request path. The AWS
# AI gateway calls it keyless: it gets a token from AWS STS (IAM outbound
# identity federation) and trades it for an Entra token through the federated
# credential below, the same shape as github.tf. Delete on day 4.

resource "azurerm_cognitive_account" "content_safety" {
  #checkov:skip=CKV_AZURE_134:Called by the AWS gateway over the internet; keyless (local auth off, Entra token by federation) is the control. Tracked in POA&M.
  #checkov:skip=CKV2_AZURE_22:Free tier, no stored customer data; Microsoft managed keys. Tracked in POA&M.
  #checkov:skip=CKV_AZURE_247:No network ACLs for the same reason as CKV_AZURE_134. Tracked in POA&M.
  name                  = "cs-meridian-${local.suffix}"
  location              = azurerm_resource_group.meridian.location
  resource_group_name   = azurerm_resource_group.meridian.name
  kind                  = "ContentSafety"
  sku_name              = "F0"
  custom_subdomain_name = "cs-meridian-${local.suffix}"
  local_auth_enabled    = false
  tags                  = merge(local.tags, { milestone = "M4" })

  identity {
    type = "SystemAssigned"
  }
}

# You, for checks from the laptop.
resource "azurerm_role_assignment" "me_content_safety" {
  scope                = azurerm_cognitive_account.content_safety.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azuread_client_config.me.object_id
}

resource "azuread_application" "aws_gateway" {
  display_name = "meridian-aws-gateway"
}

resource "azuread_service_principal" "aws_gateway" {
  client_id = azuread_application.aws_gateway.client_id
}

# Only the gateway role's token is accepted; any other AWS principal has a different subject.
resource "azuread_application_federated_identity_credential" "aws_gateway" {
  #checkov:skip=CKV_AZURE_249:The check assumes a GitHub OIDC issuer. This trusts one AWS issuer and one exact role ARN subject, the narrow form. Tracked in POA&M.
  application_id = azuread_application.aws_gateway.id
  display_name   = "aws-meridian-ai-gateway"
  issuer         = var.aws_outbound_issuer
  subject        = var.aws_gateway_role_arn
  audiences      = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "aws_gateway_content_safety" {
  scope                = azurerm_cognitive_account.content_safety.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azuread_service_principal.aws_gateway.object_id
}

output "content_safety_endpoint" {
  value = azurerm_cognitive_account.content_safety.endpoint
}

output "aws_gateway_client_id" {
  value = azuread_application.aws_gateway.client_id
}
