# GitHub OIDC federation, the pipeline deploy role, the pipeline's own state
# bucket, and the break glass alert for this account.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only the main branch of this one repo. A pull request token carries
    # sub = repo:OWNER/REPO:pull_request and is refused.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "meridian-gha-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

# Before: broad, so the first pipeline run succeeds and shows what it calls.
resource "aws_iam_role_policy_attachment" "broad" {
  count      = var.deploy_policy_mode == "broad" ? 1 : 0
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy" "broad_key_scan" {
  count = var.deploy_policy_mode == "broad" ? 1 : 0
  name  = "key-scan-read"
  role  = aws_iam_role.deploy.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["iam:GetAccountSummary", "iam:ListUsers"], Resource = "*" }]
  })
}

# After: only what Event history showed the pipeline using.
resource "aws_iam_role_policy" "scoped" {
  count = var.deploy_policy_mode == "scoped" ? 1 : 0
  name  = "scoped"
  role  = aws_iam_role.deploy.id
  policy = templatefile("${path.module}/policies/deploy-scoped.json.tftpl", {
    account_id   = data.aws_caller_identity.me.account_id
    region       = var.region
    state_bucket = module.pipeline_state.id
  })
}

module "pipeline_state" {
  source = "../../../modules/secure-bucket"
  name   = "meridian-tfstate-${var.workload_account_id}"
}

module "breakglass_alert" {
  source      = "../../../modules/breakglass-alert"
  alert_email = var.alert_email
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "pipeline_state_bucket" {
  value = module.pipeline_state.id
}
