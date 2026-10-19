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
