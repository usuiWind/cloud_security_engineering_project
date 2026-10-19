# Groups mirroring the AWS permission sets, MFA for every human, one excluded emergency account.

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

# breakglass has no standing role; the emergency account below is the real break glass.

data "azuread_user" "emergency" {
  user_principal_name = var.emergency_upn
}

resource "azuread_conditional_access_policy" "mfa" {
  display_name = "meridian-require-mfa"
  state        = "enabled"

  conditions {
    client_app_types = ["all"]
    applications {
      included_applications = ["All"]
    }
    users {
      included_users = ["All"]
      excluded_users = [data.azuread_user.emergency.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
