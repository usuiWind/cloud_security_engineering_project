variable "region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type = string
}

variable "workload_account_id" {
  type = string
}

variable "log_bucket" {
  type        = string
  description = "Log archive bucket in the management account (org stack output log_bucket)."
}

variable "subscription_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "model_id" {
  type        = string
  default     = "amazon.nova-lite-v1:0"
  description = "The one model the Bedrock endpoint policy allows. Must match envs/persistent/workload."
}

variable "lambda_model_id" {
  type        = string
  default     = "amazon.nova-lite-v1:0"
  description = "What the Lambda asks for. Set to another model only for the AC-4 endpoint policy test."
}

variable "bedrock_endpoint" {
  type        = bool
  default     = true
  description = "false removes the bedrock-runtime endpoint for the SC-7 no-path test."
}

variable "reserved_concurrency" {
  type        = number
  default     = 5
  description = "-1 if the account concurrency limit is 10 (new accounts); see runbook 3.2."
}
