# Terraform state bucket in the management account.
# First apply runs with local state. Then rename backend.tf.disabled to
# backend.tf and migrate this state into the bucket it just created.

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "owner" {
  type = string
}

provider "aws" {
  region = "us-east-1"
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

module "state" {
  source = "../../modules/secure-bucket"
  name   = "meridian-tfstate-${data.aws_caller_identity.me.account_id}"
}

output "state_bucket" {
  value = module.state.id
}
