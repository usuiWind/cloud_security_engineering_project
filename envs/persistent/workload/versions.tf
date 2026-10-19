# Applied from your laptop as PlatformAdmin in the management account.
# The provider steps into the workload account through the role that
# Organizations created there. State stays in the management state bucket.

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
    session_name = "meridian-terraform"
  }
  default_tags {
    tags = {
      project    = "meridian"
      owner      = var.owner
      milestone  = "M1"
      data_class = "internal"
    }
  }
}

data "aws_caller_identity" "me" {}
