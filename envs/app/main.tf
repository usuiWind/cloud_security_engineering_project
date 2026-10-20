# What the pipeline deploys. Session 1: one configuration parameter, enough
# to prove the federated deploy path end to end. Grows from Session 3.

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # bucket is passed by the workflow: -backend-config="bucket=..."
  backend "s3" {
    key          = "app/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

variable "owner" {
  type    = string
  default = "platform"
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

resource "aws_ssm_parameter" "model_id" {
  #checkov:skip=CKV2_AWS_34:Model id is public configuration, not a secret; String type on purpose. Tracked in POA&M.
  name        = "/meridian/config/model_id"
  description = "Bedrock model the assistant invokes. Set in Session 3."
  type        = "String"
  value       = "unset-until-session-3"
}
