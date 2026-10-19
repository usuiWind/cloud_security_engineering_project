# Emails on any API call or console sign in made with the BreakGlass
# permission set in this account. Deployed in us-east-1, where global
# services log and where all lab work happens.

variable "alert_email" {
  type = string
}

resource "aws_sns_topic" "this" {
  #checkov:skip=CKV_AWS_26:EventBridge cannot publish to a topic encrypted with the AWS managed SNS key; the alert carries no sensitive data. Tracked in POA&M.
  name = "meridian-breakglass-alert"
}

resource "aws_cloudwatch_event_rule" "this" {
  name        = "meridian-breakglass-used"
  description = "Any API call or console sign in made with the BreakGlass permission set"
  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail", "AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = {
        sessionContext = {
          sessionIssuer = {
            userName = [{ prefix = "AWSReservedSSO_BreakGlass_" }]
          }
        }
      }
    }
  })
}

data "aws_iam_policy_document" "topic" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.this.arn]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic.json
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.this.name
  arn  = aws_sns_topic.this.arn
}
