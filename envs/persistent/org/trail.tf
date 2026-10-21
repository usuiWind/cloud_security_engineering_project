# Organization trail into a log archive bucket in the management account.
# A dedicated log archive account is the production pattern; noted as a
# deviation in the POA&M.

locals {
  trail_name = "meridian-org-trail"
  trail_arn  = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.me.account_id}:trail/${local.trail_name}"
  log_bucket = "meridian-logs-${data.aws_caller_identity.me.account_id}"
  # M3: data events for this one table only, so Session 4 can show a denied GetItem.
  cases_table_arn = "arn:aws:dynamodb:${var.region}:${aws_organizations_account.workload.id}:table/meridian-cases"
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.log_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "CloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${local.log_bucket}/AWSLogs/${data.aws_caller_identity.me.account_id}/*",
      "arn:aws:s3:::${local.log_bucket}/AWSLogs/${aws_organizations_organization.this.id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  # M3: workload VPC flow logs land beside the trail, where Sentinel reads them in M5.
  statement {
    sid       = "FlowLogsAclCheck"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.log_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [aws_organizations_account.workload.id]
    }
  }

  statement {
    sid       = "FlowLogsWrite"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.log_bucket}/AWSLogs/${aws_organizations_account.workload.id}/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [aws_organizations_account.workload.id]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

data "aws_iam_policy_document" "log_archive" {
  source_policy_documents = [data.aws_iam_policy_document.cloudtrail.json, data.aws_iam_policy_document.flow_logs.json]
}

module "log_archive" {
  source      = "../../../modules/secure-bucket"
  name        = local.log_bucket
  policy_json = data.aws_iam_policy_document.log_archive.json
}

resource "aws_cloudtrail" "org" {
  #checkov:skip=CKV_AWS_35:SSE-S3 on the log archive; CMK deferred to avoid locking CloudTrail out through a key policy. Tracked in POA&M.
  #checkov:skip=CKV2_AWS_10:CloudWatch Logs delivery costs per GB; Sentinel reads the S3 archive in M5. Tracked in POA&M.
  #checkov:skip=CKV_AWS_252:Per delivery SNS not needed; break glass alerting is EventBridge. Tracked in POA&M.
  name                          = local.trail_name
  s3_bucket_name                = module.log_archive.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  advanced_event_selector {
    name = "Management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "Cases table data events"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::DynamoDB::Table"]
    }
    field_selector {
      field  = "resources.ARN"
      equals = [local.cases_table_arn]
    }
  }
  depends_on = [module.log_archive, aws_organizations_organization.this]
}
