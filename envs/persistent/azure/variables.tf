variable "owner" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "github_owner" {
  type        = string
  description = "GitHub user or org, exactly as in the repo URL"
}

variable "github_repo" {
  type = string
}

# From policy/intent.auto.tfvars
variable "allowed_regions" {
  type = map(list(string))
}

variable "required_tags" {
  type = list(string)
}

variable "protected_services" {
  type    = list(string)
  default = []
}

# M4: the AWS gateway's keyless path to Content Safety (contentsafety.tf).
variable "aws_outbound_issuer" {
  type        = string
  description = "IssuerIdentifier from aws iam get-outbound-web-identity-federation-info in the workload account (runbook 4.3)."
}

variable "aws_gateway_role_arn" {
  type        = string
  description = "arn:aws:iam::<workload account>:role/meridian-ai-gateway, the subject Entra accepts."
}

# M5
variable "defender_cspm" {
  type        = bool
  default     = true
  description = "Defender CSPM trial (CloudPosture Standard). false on day 4."
}

variable "sentinel_rules" {
  type        = bool
  default     = false
  description = "true once AWSCloudTrail has data (runbook 5.7); a rule on an empty table fails to create."
}
