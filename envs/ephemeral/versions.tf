# Everything that costs by the hour: VPC endpoints, private endpoints, the Lambda
# and its ENIs. One stack, both clouds, so one destroy ends the night.
# Applied from your laptop: AWS_PROFILE=mgmt-platform (steps into the workload
# account like envs/persistent/workload) and az login.

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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
      milestone  = "M3"
      data_class = "internal"
    }
  }
}

provider "azurerm" {
  features {
    storage {
      # The storage accounts refuse the laptop's network; manage them through ARM only.
      data_plane_available = false
    }
  }
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "core"
}

locals {
  azure_tags = {
    project    = "meridian"
    owner      = var.owner
    milestone  = "M3"
    data_class = "internal"
  }
}
