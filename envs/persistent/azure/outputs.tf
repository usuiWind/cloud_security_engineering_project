output "client_id" {
  value = azuread_application.github.client_id
}

output "tenant_id" {
  value = data.azuread_client_config.me.tenant_id
}

output "subscription_id" {
  value = var.subscription_id
}

output "management_group_id" {
  value = azurerm_management_group.meridian.id
}

output "nist_assignment_id" {
  value = azurerm_management_group_policy_assignment.nist.id
}
