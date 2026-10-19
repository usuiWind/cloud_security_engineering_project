# Organization trail into a log archive bucket in the management account.
# A dedicated log archive account is the production pattern; noted as a
# deviation in the POA&M.

locals {
  trail_name = "meridian-org-trail"
  trail_arn  = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.me.account_id}:trail/${local.trail_name}"
  log_bucket = "meridian-logs-${data.aws_caller_identity.me.account_id}"
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

module "log_archive" {
  source      = "../../../modules/secure-bucket"
  name        = local.log_bucket
  policy_json = data.aws_iam_policy_document.cloudtrail.json
}

resource "aws_cloudtrail" "org" {
  name                          = local.trail_name
  s3_bucket_name                = module.log_archive.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  depends_on                    = [module.log_archive, aws_organizations_organization.this]
}
