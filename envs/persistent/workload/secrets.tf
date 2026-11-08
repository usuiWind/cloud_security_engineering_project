# The Gemini API key. Terraform creates the secret empty; Engineer stores the
# value once (runbook 3.5b) and can never read it back. Only the gateway can.

resource "aws_secretsmanager_secret" "gemini" {
  #checkov:skip=CKV2_AWS_57:A Google AI Studio key cannot be rotated by a Lambda; rotation is manual. Tracked in POA&M.
  name                    = "meridian/gemini-api-key"
  description             = "Gemini API key for meridian-ai-gateway. Value set by hand, never in code."
  kms_key_id              = aws_kms_key.this["secrets"].arn
  recovery_window_in_days = 7
  tags                    = local.m3_tags
}

data "aws_iam_policy_document" "gemini_secret" {
  statement {
    sid       = "OnlyTheGatewayReads"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.gateway.arn]
    }
  }
}

resource "aws_secretsmanager_secret_policy" "gemini" {
  secret_arn = aws_secretsmanager_secret.gemini.arn
  policy     = data.aws_iam_policy_document.gemini_secret.json
}

output "gemini_secret_arn" {
  value = aws_secretsmanager_secret.gemini.arn
}
