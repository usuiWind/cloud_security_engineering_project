# M2 guardrails on the workloads OU, rendered from policy/intent.auto.tfvars.
# Two policies to stay under the 5,120 character SCP limit. SCPs never apply
# to the management account, so every test runs in the workload account.

locals {
  # Global services answer from us-east-1 whatever region is asked, so they
  # are exempt from the region deny.
  global_actions = [
    "account:*", "budgets:*", "ce:*", "cloudfront:*", "cur:*", "health:*",
    "iam:*", "identitystore:*", "organizations:*", "pricing:*", "route53:*",
    "route53domains:*", "s3:GetAccountPublic*", "s3:ListAllMyBuckets",
    "sso:*", "sts:*", "support:*", "trustedadvisor:*",
  ]

  protected_actions = {
    cloudtrail = ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail", "cloudtrail:UpdateTrail"]
    guardduty  = ["guardduty:DeleteDetector", "guardduty:Disassociate*"]
    kms        = ["kms:ScheduleKeyDeletion", "kms:DisableKey"]
  }

  tag_on_create_actions = ["lambda:CreateFunction", "dynamodb:CreateTable", "kms:CreateKey", "ec2:CreateVpc"]

  breakglass_arn = "arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*AWSReservedSSO_BreakGlass_*"
}

resource "aws_organizations_policy" "region" {
  name        = "meridian-allowed-regions"
  description = "Deny every regional action outside allowed_regions.aws"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyOutsideAllowedRegions"
      Effect    = "Deny"
      NotAction = local.global_actions
      Resource  = "*"
      Condition = { StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions.aws } }
    }]
  })
}

resource "aws_organizations_policy" "guardrails" {
  name        = "meridian-guardrails"
  description = "Protected security services, account public access block, IMDSv2, tags on create"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "ProtectSecurityServices"
          Effect    = "Deny"
          Action    = flatten([for s in var.protected_services : local.protected_actions[s]])
          Resource  = "*"
          Condition = { ArnNotLike = { "aws:PrincipalArn" = local.breakglass_arn } }
        },
        {
          Sid      = "LockAccountPublicAccessBlock"
          Effect   = "Deny"
          Action   = "s3:PutAccountPublicAccessBlock"
          Resource = "*"
        },
        {
          Sid       = "RequireImdsV2"
          Effect    = "Deny"
          Action    = "ec2:RunInstances"
          Resource  = "arn:aws:ec2:*:*:instance/*"
          Condition = { StringNotEquals = { "ec2:MetadataHttpTokens" = "required" } }
        },
      ],
      # One statement per tag, so a denial names the missing tag.
      [for t in var.required_tags : {
        Sid       = "RequireTag${replace(t, "_", "")}"
        Effect    = "Deny"
        Action    = local.tag_on_create_actions
        Resource  = "*"
        Condition = { Null = { "aws:RequestTag/${t}" = "true" } }
      }]
    )
  })
}

resource "aws_organizations_policy_attachment" "region" {
  policy_id = aws_organizations_policy.region.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "guardrails" {
  policy_id = aws_organizations_policy.guardrails.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

output "scp_ids" {
  value = [aws_organizations_policy.region.id, aws_organizations_policy.guardrails.id]
}
