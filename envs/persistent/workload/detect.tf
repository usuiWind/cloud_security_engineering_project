# M5 detection, AWS side. All trials start the day this applies (runbook 5.3);
# detection = false is the day 4 teardown (runbook 6.10).
#
# GuardDuty is never destroyed: the SCP denies guardduty:DeleteDetector to all
# but BreakGlass, so teardown suspends it (enable = false), which costs nothing.

resource "aws_guardduty_detector" "this" {
  #checkov:skip=CKV2_AWS_3:One workload account; no GuardDuty org admin or member auto-enable in the lab. Tracked in POA&M.
  enable = var.detection
  tags   = { milestone = "M5" }
}

# S3 data events (the corpus) and Lambda network activity (the app and the gateway) on; the rest off.
resource "aws_guardduty_detector_feature" "this" {
  for_each = {
    S3_DATA_EVENTS         = "ENABLED"
    LAMBDA_NETWORK_LOGS    = "ENABLED"
    EKS_AUDIT_LOGS         = "DISABLED"
    EBS_MALWARE_PROTECTION = "DISABLED"
    RDS_LOGIN_EVENTS       = "DISABLED"
    RUNTIME_MONITORING     = "DISABLED"
  }
  detector_id = aws_guardduty_detector.this.id
  name        = each.key
  status      = each.value
}

resource "aws_securityhub_account" "this" {
  count                    = var.detection ? 1 : 0
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.detection ? 1 : 0
  standards_arn = "arn:aws:securityhub:${var.region}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# Config records only the lab's resource types, so it costs cents.
resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid       = "ConfigAclCheck"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = ["arn:aws:s3:::meridian-config-${local.account_id}"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
  statement {
    sid       = "ConfigWrite"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::meridian-config-${local.account_id}/AWSLogs/${local.account_id}/Config/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# The bucket stays after teardown: it holds the recorded history, and destroy would need it empty.
module "config_bucket" {
  source      = "../../../modules/secure-bucket"
  name        = "meridian-config-${local.account_id}"
  policy_json = data.aws_iam_policy_document.config_bucket.json
}

resource "aws_config_configuration_recorder" "this" {
  #checkov:skip=CKV2_AWS_48:Records the eight lab resource types only, by design, so Config costs cents. Tracked in POA&M.
  count    = var.detection ? 1 : 0
  name     = "default"
  role_arn = aws_iam_service_linked_role.config.arn
  recording_group {
    all_supported = false
    resource_types = [
      "AWS::Lambda::Function", "AWS::S3::Bucket", "AWS::DynamoDB::Table", "AWS::KMS::Key",
      "AWS::IAM::Role", "AWS::EC2::VPC", "AWS::EC2::SecurityGroup", "AWS::EC2::VPCEndpoint",
    ]
  }
}

resource "aws_config_delivery_channel" "this" {
  count          = var.detection ? 1 : 0
  name           = "default"
  s3_bucket_name = module.config_bucket.id
  depends_on     = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  #checkov:skip=CKV2_AWS_45:Same as CKV2_AWS_48: lab resource types only. Tracked in POA&M.
  count      = var.detection ? 1 : 0
  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# R3 fallback (runbook 5.6): if the CloudWatch export to Sentinel fails, the
# spike rule lives here instead. The alarm state is the detection; no action.
resource "aws_cloudwatch_log_metric_filter" "guardrail" {
  count          = var.guardrail_alarm ? 1 : 0
  name           = "meridian-guardrail-intervened"
  log_group_name = "/aws/lambda/meridian-app"
  pattern        = "{ $.event = \"guardrail_intervened\" }"
  metric_transformation {
    name      = "GuardrailIntervened"
    namespace = "Meridian"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "guardrail" {
  count               = var.guardrail_alarm ? 1 : 0
  alarm_name          = "meridian-injection-spike"
  alarm_description   = "R3: 5 or more guardrail interventions in 10 minutes"
  namespace           = "Meridian"
  metric_name         = "GuardrailIntervened"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}
