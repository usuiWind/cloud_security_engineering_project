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

variable "gateway_function" {
  type        = string
  default     = "meridian-ai-gateway"
  description = "What the app invokes. Set to another function name only for the AC-4 endpoint policy test."
}

variable "gateway_endpoint" {
  type        = bool
  default     = true
  description = "false removes the lambda interface endpoint for the SC-7 no-path test."
}

variable "reserved_concurrency" {
  type        = number
  default     = 5
  description = "-1 if the account concurrency limit is 10 (new accounts); see runbook 3.2."
}

# M4 runs. A = no guard layer; B = Prompt Shields and Content Safety through the
# gateway; C = B plus the link allowlist (and scoped_tools in envs/persistent/workload).
variable "stage" {
  type        = string
  default     = "C"
  description = "A, B or C. C is the end state."
  validation {
    condition     = contains(["A", "B", "C"], var.stage)
    error_message = "stage must be A, B or C."
  }
  validation {
    condition     = var.stage == "A" || (var.content_safety_endpoint != "" && var.gateway_client_id != "")
    error_message = "Stages B and C need content_safety_endpoint and gateway_client_id (outputs of envs/persistent/azure)."
  }
}

variable "link_allowlist" {
  type    = list(string)
  default = ["benefits.example.gov"]
}

variable "azure_tenant_id" {
  type    = string
  default = "201d985b-1557-4012-9958-564c74cb2d60"
}

variable "gateway_client_id" {
  type        = string
  default     = ""
  description = "aws_gateway_client_id output of envs/persistent/azure."
}

variable "content_safety_endpoint" {
  type        = string
  default     = ""
  description = "content_safety_endpoint output of envs/persistent/azure."
}
