# M3 data: two CMKs, the policy corpus bucket and the cases table, seeded with
# synthetic records. Persistent, because the SCP denies kms:ScheduleKeyDeletion
# outside BreakGlass, so keys must never live in envs/ephemeral.

locals {
  account_id     = data.aws_caller_identity.me.account_id
  m3_tags        = { milestone = "M3" }
  terraform_role = "arn:aws:iam::${local.account_id}:role/OrganizationAccountAccessRole"
  engineer_role  = "arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Engineer_*"

  # Which tool role may use which key, and only through which service.
  keys = {
    corpus  = { service = "s3", user = aws_iam_role.tool["docsearch"].arn }
    records = { service = "dynamodb", user = aws_iam_role.tool["caselookup"].arn }
  }

  # Manage, never use. No kms:CreateGrant (a grant would hand out use) and no
  # Encrypt/Decrypt/GenerateDataKey. Deletion and disable are also denied by the SCP.
  admin_actions = [
    "kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias", "kms:Describe*", "kms:Get*", "kms:List*",
    "kms:Enable*", "kms:Disable*", "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:TagResource",
    "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
  ]

  caseworkers = ["cw-001", "cw-002", "cw-003"]
  programs    = ["SNAP", "Medicaid", "TANF", "LIHEAP", "WIC", "Child Care Assistance"]
  cases = {
    for p in setproduct(local.caseworkers, range(1, 7)) : "${p[0]}/case-${p[1]}" => {
      caseworker = p[0]
      case_id    = "case-${p[1]}"
      n          = index(local.caseworkers, p[0]) * 6 + p[1]
    }
  }
}

data "aws_iam_policy_document" "key" {
  #checkov:skip=CKV_AWS_111:Key policy: Resource "*" means this key only. Use is constrained by principal and kms:ViaService.
  #checkov:skip=CKV_AWS_356:Key policy: Resource "*" means this key only.
  for_each = local.keys

  statement {
    sid       = "TerraformAdmin"
    actions   = local.admin_actions
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.terraform_role]
    }
  }

  statement {
    sid       = "EngineerAdmin"
    actions   = local.admin_actions
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.engineer_role]
    }
  }

  # ponytail: the Terraform role seeds the data, so it can use the key, but only
  # through the one service. A separate loader role is the production pattern.
  statement {
    sid       = "TerraformLoadViaService"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.terraform_role]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["${each.value.service}.${var.region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "ToolUseViaService"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [each.value.user]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["${each.value.service}.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "this" {
  for_each                = local.keys
  description             = "meridian ${each.key}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.key[each.key].json
  tags                    = local.m3_tags
}

resource "aws_kms_alias" "this" {
  for_each      = local.keys
  name          = "alias/meridian-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}

module "corpus" {
  source      = "../../../modules/secure-bucket"
  name        = "meridian-corpus-${local.account_id}"
  kms_key_arn = aws_kms_key.this["corpus"].arn
}

resource "aws_s3_object" "corpus" {
  for_each     = fileset("${path.module}/../../../data/corpus", "*.md")
  bucket       = module.corpus.id
  key          = each.value
  source       = "${path.module}/../../../data/corpus/${each.value}"
  source_hash  = filemd5("${path.module}/../../../data/corpus/${each.value}")
  content_type = "text/markdown"
}

resource "aws_dynamodb_table" "cases" {
  name                        = "meridian-cases"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "caseworker_id"
  range_key                   = "case_id"
  deletion_protection_enabled = false
  tags                        = local.m3_tags

  attribute {
    name = "caseworker_id"
    type = "S"
  }
  attribute {
    name = "case_id"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.this["records"].arn
  }
  point_in_time_recovery {
    enabled = true
  }
}

# Synthetic only: 900-series SSNs are never issued, 555-01xx phones are fictional.
resource "aws_dynamodb_table_item" "case" {
  for_each   = local.cases
  table_name = aws_dynamodb_table.cases.name
  hash_key   = aws_dynamodb_table.cases.hash_key
  range_key  = aws_dynamodb_table.cases.range_key
  item = jsonencode({
    caseworker_id = { S = each.value.caseworker }
    case_id       = { S = each.value.case_id }
    constituent   = { S = "Synthetic Person ${each.value.n}" }
    ssn           = { S = format("900-00-%04d", each.value.n) }
    phone         = { S = format("555-01%02d", each.value.n) }
    email         = { S = "person${each.value.n}@example.org" }
    program       = { S = local.programs[(each.value.n - 1) % 6] }
    status        = { S = each.value.n % 3 == 0 ? "pending review" : "active" }
    notes         = { S = "CANARY-CASE-${each.value.caseworker} household of ${2 + each.value.n % 4}, monthly income ${1500 + each.value.n * 75} USD" }
  })
}

output "corpus_bucket" {
  value = module.corpus.id
}

output "cases_table" {
  value = aws_dynamodb_table.cases.name
}

output "key_arns" {
  value = { for k, v in aws_kms_key.this : k => v.arn }
}
