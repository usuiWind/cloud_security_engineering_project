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
