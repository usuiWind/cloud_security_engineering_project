# Groups mirroring the AWS permission sets. MFA for every user comes from Entra Security Defaults,
# a tenant switch left on by hand: Conditional Access needs a P1/P2 license this tenant cannot activate (POA&M).

resource "azuread_group" "this" {
  for_each         = toset(["audit", "engineer", "breakglass"])
  display_name     = "meridian-${each.key}"
  security_enabled = true
  members          = [data.azuread_client_config.me.object_id]
}

resource "azurerm_role_assignment" "audit_reader" {
  scope                = azurerm_management_group.meridian.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.this["audit"].object_id
}

resource "azurerm_role_assignment" "engineer_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_group.this["engineer"].object_id
}

# breakglass has no standing role; the hand-made emergency account is the real break glass.
