# Applied from your laptop: az login as your tenant admin, AWS_PROFILE=mgmt-platform for state.
# State lives in the same S3 state bucket as the AWS stacks, key azure/terraform.tfstate.

terraform {
  required_version = ">= 1.11.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
  backend "s3" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # The default registers ~70 providers (Databricks, AVS...) and takes minutes on a new subscription.
  resource_provider_registrations = "core"
  resource_providers_to_register  = ["Microsoft.PolicyInsights", "Microsoft.KeyVault", "Microsoft.OperationalInsights", "Microsoft.Insights"]
}

provider "azuread" {}

data "azuread_client_config" "me" {}

locals {
  tags = {
    project    = "meridian"
    owner      = var.owner
    milestone  = "M2"
    data_class = "internal"
  }
}
