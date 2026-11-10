# M5 detection, Azure side: one Log Analytics workspace with Sentinel on it,
# the Defender CSPM trial, and the subscription Activity log into the workspace.
# AWS CloudTrail and VPC flow logs arrive through the Sentinel S3 connector
# (runbook 5.5, made by Microsoft's script, not here).

resource "azurerm_log_analytics_workspace" "meridian" {
  name                = "law-meridian"
  location            = azurerm_resource_group.meridian.location
  resource_group_name = azurerm_resource_group.meridian.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  # The free account's guard: Sentinel's trial covers 10 GB a day; this stops at 1.
  daily_quota_gb = 1
  tags           = merge(local.tags, { milestone = "M5" })
}

# Onboarding makes a SecurityInsights solution resource with no tags, which the
# meridian-baseline tag deny refuses. Create it here, tagged, before onboarding runs.
resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = azurerm_resource_group.meridian.location
  resource_group_name   = azurerm_resource_group.meridian.name
  workspace_resource_id = azurerm_log_analytics_workspace.meridian.id
  workspace_name        = azurerm_log_analytics_workspace.meridian.name
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
  tags = merge(local.tags, { milestone = "M5" })
}

# Onboarding re-PUTs that solution without tags. Waive the tag rules on that one
# resource only; an RG-scope exemption would also blind the rg-meridian tag tests.
resource "azurerm_resource_policy_exemption" "sentinel_tags" {
  name                            = "sentinel-solution-tags"
  resource_id                     = azurerm_log_analytics_solution.sentinel.id
  policy_assignment_id            = azurerm_management_group_policy_assignment.baseline.id
  exemption_category              = "Waiver"
  policy_definition_reference_ids = [for t in var.required_tags : "resource-tag-${t}"]
  description                     = "Sentinel onboarding writes the SecurityInsights solution without tags; Terraform tags it."
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "meridian" {
  workspace_id = azurerm_log_analytics_workspace.meridian.id
  depends_on   = [azurerm_resource_policy_exemption.sentinel_tags]
}

# Day 4: defender_cspm = false puts the plan back to Free.
resource "azurerm_security_center_subscription_pricing" "cspm" {
  tier          = var.defender_cspm ? "Standard" : "Free"
  resource_type = "CloudPosture"
}

resource "azurerm_monitor_diagnostic_setting" "activity" {
  name                       = "meridian-activity-to-sentinel"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.meridian.id
  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert"]
    content {
      category = enabled_log.value
    }
  }
}

output "workspace_id" {
  description = "The workspace GUID, for az monitor log-analytics query and the S3 connector."
  value       = azurerm_log_analytics_workspace.meridian.workspace_id
}

output "workspace_resource_id" {
  value = azurerm_log_analytics_workspace.meridian.id
}
