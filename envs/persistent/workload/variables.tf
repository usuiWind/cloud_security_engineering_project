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

variable "github_owner" {
  type        = string
  description = "GitHub user or org, exactly as it appears in the repo URL"
}

variable "github_repo" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "deploy_policy_mode" {
  type        = string
  default     = "broad"
  description = "broad = PowerUserAccess for the first run; scoped = the least privilege policy in policies/"
  validation {
    condition     = contains(["broad", "scoped"], var.deploy_policy_mode)
    error_message = "deploy_policy_mode must be broad or scoped."
  }
}
