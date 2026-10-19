# Identity Center must already be enabled (Session 1 Part A).
# Four permission sets, assigned to one group, never to a user directly.
#   AuditReadOnly  both accounts      read only, 4 h
#   Engineer       workload only      PowerUser minus trail and org changes, 8 h
#   PlatformAdmin  management only    applies the persistent stacks, 1 h
#   BreakGlass     both accounts      emergencies only, alerts on any use, 1 h

data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
  mgmt_account      = data.aws_caller_identity.me.account_id
  workload_account  = aws_organizations_account.workload.id

  permission_sets = {
    AuditReadOnly = { session = "PT4H", managed = ["arn:aws:iam::aws:policy/SecurityAudit", "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"] }
    Engineer      = { session = "PT8H", managed = ["arn:aws:iam::aws:policy/PowerUserAccess"] }
    PlatformAdmin = { session = "PT1H", managed = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
    BreakGlass    = { session = "PT1H", managed = ["arn:aws:iam::aws:policy/AdministratorAccess"] }
  }

  managed_attachments = merge([
    for name, ps in local.permission_sets : {
      for arn in ps.managed : "${name}|${arn}" => { ps = name, arn = arn }
    }
  ]...)

  assignments = {
    "mgmt-AuditReadOnly"     = { ps = "AuditReadOnly", account = local.mgmt_account }
    "mgmt-PlatformAdmin"     = { ps = "PlatformAdmin", account = local.mgmt_account }
    "mgmt-BreakGlass"        = { ps = "BreakGlass", account = local.mgmt_account }
    "workload-AuditReadOnly" = { ps = "AuditReadOnly", account = local.workload_account }
    "workload-Engineer"      = { ps = "Engineer", account = local.workload_account }
    "workload-BreakGlass"    = { ps = "BreakGlass", account = local.workload_account }
  }
}

data "aws_identitystore_user" "me" {
  identity_store_id = local.identity_store_id
  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.sso_username
    }
  }
}

resource "aws_identitystore_group" "platform" {
  identity_store_id = local.identity_store_id
  display_name      = "meridian-platform"
  description       = "Meridian platform engineers"
}

resource "aws_identitystore_group_membership" "me" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.platform.group_id
  member_id         = data.aws_identitystore_user.me.user_id
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each         = local.permission_sets
  name             = each.key
  instance_arn     = local.sso_instance_arn
  session_duration = each.value.session
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each           = local.managed_attachments
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn
  managed_policy_arn = each.value.arn
}

data "aws_iam_policy_document" "engineer_guard" {
  statement {
    sid    = "NoTrailOrOrgTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "engineer" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this["Engineer"].arn
  inline_policy      = data.aws_iam_policy_document.engineer_guard.json
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = local.assignments
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn
  principal_id       = aws_identitystore_group.platform.group_id
  principal_type     = "GROUP"
  target_id          = each.value.account
  target_type        = "AWS_ACCOUNT"
  depends_on = [
    aws_ssoadmin_managed_policy_attachment.this,
    aws_ssoadmin_permission_set_inline_policy.engineer,
  ]
}

module "breakglass_alert" {
  source      = "../../../modules/breakglass-alert"
  alert_email = var.alert_email
}
