# M3 roles. app-task runs the Lambda and touches no data. Each tool runs
# under its own role, assumed per call; caselookup carries the caller as a
# session tag so Session 4 can bind reads to it.

locals {
  model_arn = "arn:aws:bedrock:${var.region}::foundation-model/${var.model_id}"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "app_task" {
  name               = "meridian-app-task"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.m3_tags
}

resource "aws_iam_role_policy_attachment" "app_task_vpc" {
  role       = aws_iam_role.app_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "app_task" {
  name = "app"
  role = aws_iam_role.app_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OneModel", Effect = "Allow", Action = "bedrock:InvokeModel", Resource = local.model_arn },
      { Sid = "ToolRoles", Effect = "Allow", Action = ["sts:AssumeRole", "sts:TagSession"], Resource = [for r in aws_iam_role.tool : r.arn] },
    ]
  })
}

data "aws_iam_policy_document" "tool_trust" {
  for_each = toset(["docsearch", "caselookup"])
  statement {
    actions = each.key == "caselookup" ? ["sts:AssumeRole", "sts:TagSession"] : ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.app_task.arn]
    }
    # caselookup is refused unless the caller rides along as a session tag.
    dynamic "condition" {
      for_each = each.key == "caselookup" ? [1] : []
      content {
        test     = "Null"
        variable = "aws:RequestTag/caseworker"
        values   = ["false"]
      }
    }
  }
}

resource "aws_iam_role" "tool" {
  for_each             = toset(["docsearch", "caselookup"])
  name                 = "meridian-tool-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.tool_trust[each.key].json
  max_session_duration = 3600
  tags                 = local.m3_tags
}

resource "aws_iam_role_policy" "docsearch" {
  name = "corpus-read"
  role = aws_iam_role.tool["docsearch"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "s3:ListBucket", Resource = module.corpus.arn },
      { Effect = "Allow", Action = "s3:GetObject", Resource = "${module.corpus.arn}/*" },
    ]
  })
}

# scoped_tools = false is the Session 4 baseline (run A); true binds every
# read to the caller's own partition key.
resource "aws_iam_role_policy" "caselookup" {
  name = "cases-read"
  role = aws_iam_role.tool["caselookup"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [merge(
      { Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:Query"], Resource = aws_dynamodb_table.cases.arn },
      var.scoped_tools ? { Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["$${aws:PrincipalTag/caseworker}"] } } } : {},
    )]
  })
}

output "app_task_role_arn" {
  value = aws_iam_role.app_task.arn
}

output "tool_role_arns" {
  value = { for k, v in aws_iam_role.tool : k => v.arn }
}
