variable "region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type = string
}

variable "org_id" {
  type        = string
  description = "Existing organization id (o-xxxxxxxxxx), imported on first apply."
}

variable "workload_account_email" {
  type        = string
  description = "Unused email for the workload account root, for example you+meridian-workload@gmail.com"
}

variable "sso_username" {
  type        = string
  description = "Your Identity Center user name"
}

variable "alert_email" {
  type = string
}

variable "budget_limit_usd" {
  type    = string
  default = "75"
}
