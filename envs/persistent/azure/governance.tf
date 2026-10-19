# Management group, a Deny initiative rendered from policy/intent.auto.tfvars, and the
# NIST SP 800-53 Rev. 5 initiative in audit mode so it has history by Session 5.

resource "azurerm_management_group" "meridian" {
  name             = "meridian"
  display_name     = "meridian"
  subscription_ids = [var.subscription_id]
}

# Built-in definitions by id; a wrong id fails at plan, not at test time.
locals {
  builtin = {
    allowed_locations = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
    rg_tag            = "96670d01-0a4d-4649-9c89-2d3abc0a5025"
    resource_tag      = "871b6d14-10aa-478d-b590-94f262ecfa99"
    storage_public    = "4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
    storage_tls       = "404c3081-a854-4457-ae30-26a93ef643f9"
    keyvault_public   = "405c5871-3e91-4644-8a63-58e19d68ff5b"
    nist_800_53_rev5  = "179d1daa-458f-4e47-8086-2a68d0d6c38f"
  }
}

data "azurerm_policy_definition" "this" {
  for_each = { for k, v in local.builtin : k => v if k != "nist_800_53_rev5" }
  name     = each.value
}

resource "azurerm_management_group_policy_set_definition" "baseline" {
  name                = "meridian-baseline"
  display_name        = "meridian baseline"
  policy_type         = "Custom"
  management_group_id = azurerm_management_group.meridian.id

  policy_definition_reference {
    reference_id         = "allowed-locations"
    policy_definition_id = data.azurerm_policy_definition.this["allowed_locations"].id
    parameter_values     = jsonencode({ listOfAllowedLocations = { value = var.allowed_regions.azure } })
  }

  dynamic "policy_definition_reference" {
    for_each = var.required_tags
    content {
      reference_id         = "rg-tag-${policy_definition_reference.value}"
      policy_definition_id = data.azurerm_policy_definition.this["rg_tag"].id
      parameter_values     = jsonencode({ tagName = { value = policy_definition_reference.value } })
    }
  }

  dynamic "policy_definition_reference" {
    for_each = var.required_tags
    content {
      reference_id         = "resource-tag-${policy_definition_reference.value}"
      policy_definition_id = data.azurerm_policy_definition.this["resource_tag"].id
      parameter_values     = jsonencode({ tagName = { value = policy_definition_reference.value } })
    }
  }

  policy_definition_reference {
    reference_id         = "storage-no-public-blob"
    policy_definition_id = data.azurerm_policy_definition.this["storage_public"].id
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }

  policy_definition_reference {
    reference_id         = "storage-secure-transfer"
    policy_definition_id = data.azurerm_policy_definition.this["storage_tls"].id
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }

  policy_definition_reference {
    reference_id         = "keyvault-no-public-network"
    policy_definition_id = data.azurerm_policy_definition.this["keyvault_public"].id
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }
}

resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "meridian-baseline"
  display_name         = "meridian baseline"
  management_group_id  = azurerm_management_group.meridian.id
  policy_definition_id = azurerm_management_group_policy_set_definition.baseline.id
}

# Audit only: evaluates compliance, enforces nothing. Identity is required because the
# initiative contains DeployIfNotExists policies; it gets no role, so nothing remediates.
resource "azurerm_management_group_policy_assignment" "nist" {
  name                 = "meridian-nist-800-53"
  display_name         = "NIST SP 800-53 Rev. 5 (audit)"
  management_group_id  = azurerm_management_group.meridian.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/${local.builtin.nist_800_53_rev5}"
  enforce              = false
  location             = var.allowed_regions.azure[0]

  identity {
    type = "SystemAssigned"
  }
}

# Tagged home for the violation tests and the Session 3 resources.
resource "azurerm_resource_group" "meridian" {
  name     = "rg-meridian"
  location = var.allowed_regions.azure[0]
  tags     = local.tags
}
