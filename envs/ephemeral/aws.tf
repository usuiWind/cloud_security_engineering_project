# One private subnet, no internet gateway, no NAT. The only ways out are four
# endpoints, and each endpoint policy names what may cross it. The model is
# behind meridian-ai-gateway, outside the VPC, reached through the lambda endpoint.

locals {
  app_task_arn = "arn:aws:iam::${var.workload_account_id}:role/meridian-app-task"
  tool_arns = {
    docsearch  = "arn:aws:iam::${var.workload_account_id}:role/meridian-tool-docsearch"
    caselookup = "arn:aws:iam::${var.workload_account_id}:role/meridian-tool-caselookup"
  }
  corpus_arn  = "arn:aws:s3:::meridian-corpus-${var.workload_account_id}"
  cases_arn   = "arn:aws:dynamodb:${var.region}:${var.workload_account_id}:table/meridian-cases"
  gateway_arn = "arn:aws:lambda:${var.region}:${var.workload_account_id}:function:meridian-ai-gateway"
  # Invoke may name the function or a qualified version of it.
  gateway_resources = [local.gateway_arn, "${local.gateway_arn}:*"]

  interface = merge(
    { sts = data.aws_iam_policy_document.sts_endpoint.json },
    var.gateway_endpoint ? { lambda = data.aws_iam_policy_document.lambda_endpoint.json } : {},
  )
}

resource "aws_vpc" "this" {
  cidr_block           = "10.40.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "meridian" }
}

# Adopt the default security group and strip its rules.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

# ponytail: one AZ (POA&M). If an endpoint says the service is not offered in
# this AZ, try "b".
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.40.0.0/26"
  availability_zone = "${var.region}a"
  tags              = { Name = "meridian-private" }
}

resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "arn:aws:s3:::${var.log_bucket}"
  max_aggregation_interval = 60
}

# Gateway endpoints are free; their policies are the crossing to the data stores.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [local.corpus_arn, "${local.corpus_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "dynamodb_endpoint" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [local.cases_arn]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = {
    s3       = data.aws_iam_policy_document.s3_endpoint.json
    dynamodb = data.aws_iam_policy_document.dynamodb_endpoint.json
  }
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.this.main_route_table_id]
  policy            = each.value
}

data "aws_iam_policy_document" "lambda_endpoint" {
  statement {
    sid       = "AppTaskOnly"
    actions   = ["lambda:InvokeFunction"]
    resources = local.gateway_resources
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [local.app_task_arn]
    }
  }
  # Explicit, so invoking any other function names the endpoint policy in the denial.
  statement {
    sid           = "NothingElse"
    effect        = "Deny"
    actions       = ["lambda:*"]
    not_resources = local.gateway_resources
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "sts_endpoint" {
  statement {
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = values(local.tool_arns)
    principals {
      type        = "AWS"
      identifiers = [local.app_task_arn]
    }
  }
}

resource "aws_security_group" "lambda" {
  name        = "meridian-lambda"
  description = "Lambda ENI: egress 443 to the endpoints and the gateway prefix lists only"
  vpc_id      = aws_vpc.this.id
}

resource "aws_security_group" "endpoints" {
  name        = "meridian-endpoints"
  description = "Interface endpoints: ingress 443 from the Lambda only"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_endpoints" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "HTTPS to interface endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoints.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_gateways" {
  for_each          = aws_vpc_endpoint.gateway
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS to ${each.key} through its gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = each.value.prefix_list_id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_lambda" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the Lambda"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.lambda.id
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  policy              = each.value
}

data "archive_file" "app" {
  type        = "zip"
  source_file = "${path.module}/../../app/handler.py"
  output_path = "${path.module}/build/app.zip"
}

data "archive_file" "gateway" {
  type        = "zip"
  source_file = "${path.module}/../../app/gateway.py"
  output_path = "${path.module}/build/gateway.zip"
}

# The one function that reaches the model provider. Outside the VPC on
# purpose: it is the egress. Its code pins the host (POA&M: the network does not).
resource "aws_lambda_function" "gateway" {
  #checkov:skip=CKV_AWS_117:Outside a VPC by design; it is the single egress to the model provider. Tracked in POA&M.
  #checkov:skip=CKV_AWS_116:Invoked synchronously by meridian-app only; a DLQ has nothing to hold. Tracked in POA&M.
  #checkov:skip=CKV_AWS_173:Environment holds a secret name and a parameter name, not the key. Tracked in POA&M.
  #checkov:skip=CKV_AWS_272:Code signing set to Enforce arrives in M6 (supply chain). Tracked in POA&M.
  #checkov:skip=CKV_AWS_50:No X-Ray in the lab. Tracked in POA&M.
  function_name                  = "meridian-ai-gateway"
  role                           = "arn:aws:iam::${var.workload_account_id}:role/meridian-ai-gateway"
  runtime                        = "python3.12"
  handler                        = "gateway.handler"
  filename                       = data.archive_file.gateway.output_path
  source_code_hash               = data.archive_file.gateway.output_base64sha256
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = {
      SECRET_ID   = "meridian/gemini-api-key"
      MODEL_PARAM = "/meridian/config/model_id"
      # M4: keyless Content Safety (outputs of envs/persistent/azure). Ids and a URL, no secret.
      AZURE_TENANT_ID         = var.azure_tenant_id
      AZURE_CLIENT_ID         = var.gateway_client_id
      CONTENT_SAFETY_ENDPOINT = var.content_safety_endpoint
    }
  }
}

resource "aws_lambda_function" "app" {
  #checkov:skip=CKV_AWS_116:Invoked synchronously only; the caller sees every failure, so a DLQ has nothing to hold. Tracked in POA&M.
  #checkov:skip=CKV_AWS_173:Environment holds ids and ARNs, no secrets; default Lambda encryption at rest. Tracked in POA&M.
  #checkov:skip=CKV_AWS_272:Code signing set to Enforce arrives in M6 (supply chain). Tracked in POA&M.
  #checkov:skip=CKV_AWS_50:No X-Ray: it would need another interface endpoint for a lab with one function. Tracked in POA&M.
  function_name    = "meridian-app"
  role             = local.app_task_arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.app.output_path
  source_code_hash = data.archive_file.app.output_base64sha256
  # Up to 4 model calls, each with the gateway's 429 backoff, plus the tools.
  timeout                        = 120
  memory_size                    = 256
  reserved_concurrent_executions = var.reserved_concurrency

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      GATEWAY_FUNCTION    = var.gateway_function
      STAGE               = var.stage
      LINK_ALLOWLIST      = var.stage == "C" ? join(",", var.link_allowlist) : ""
      CORPUS_BUCKET       = "meridian-corpus-${var.workload_account_id}"
      CASES_TABLE         = "meridian-cases"
      DOCSEARCH_ROLE_ARN  = local.tool_arns.docsearch
      CASELOOKUP_ROLE_ARN = local.tool_arns.caselookup
      # Regional STS, so the call resolves to the sts interface endpoint.
      AWS_STS_REGIONAL_ENDPOINTS = "regional"
    }
  }

  # The SG and endpoints must exist before the first invoke, and must outlive
  # the function on destroy so its ENIs can drain.
  depends_on = [aws_vpc_endpoint.interface, aws_vpc_endpoint.gateway, aws_vpc_security_group_egress_rule.lambda_to_endpoints]
}

output "function_name" {
  value = aws_lambda_function.app.function_name
}

output "gateway_function_name" {
  value = aws_lambda_function.gateway.function_name
}
