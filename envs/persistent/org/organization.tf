# The organization already exists (Identity Center created it). Import it so
# trusted access and policy types live in code.
import {
  to = aws_organizations_organization.this
  id = var.org_id
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
  # Plan must show no removals here. If it does, add the missing principal.
  aws_service_access_principals = [
    "sso.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "iam.amazonaws.com",
  ]
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# Creates OrganizationAccountAccessRole in the new account by default.
resource "aws_organizations_account" "workload" {
  name              = "meridian-workload"
  email             = var.workload_account_email
  parent_id         = aws_organizations_organizational_unit.workloads.id
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }
}

# Centralized root access: member accounts carry no root password or keys.
resource "aws_iam_organizations_features" "root" {
  enabled_features = ["RootCredentialsManagement", "RootSessions"]
  depends_on       = [aws_organizations_organization.this]
}
