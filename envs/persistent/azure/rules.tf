# One scheduled Sentinel rule per detections/*.kql. Every 5 minutes over a
# 1 hour lookback, because S3 delivery lags 5 to 20 minutes. A rule fails to
# create while its table has no data yet, so sentinel_rules stays false until
# the connector has delivered (runbook 5.7).

resource "azurerm_sentinel_alert_rule_scheduled" "this" {
  for_each                   = var.sentinel_rules ? fileset("${path.module}/../../../detections", "*.kql") : []
  name                       = "meridian-${trimsuffix(each.value, ".kql")}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.meridian.workspace_id
  display_name               = "Meridian ${trimsuffix(each.value, ".kql")}"
  severity                   = "Medium"
  query                      = file("${path.module}/../../../detections/${each.value}")
  query_frequency            = "PT5M"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  # One incident per event, not one per 5 minute run for the whole 1h lookback.
  # ponytail: a second distinct event inside the hour is not a new incident.
  suppression_enabled  = true
  suppression_duration = "PT1H"

  incident {
    create_incident_enabled = true
    grouping {
      enabled = false
    }
  }
}
