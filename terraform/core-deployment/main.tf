terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.40.0"
    }
  }

  backend "s3" {
    // Backend state MUST be properly confgured and is specific to deployment environment.
    bucket = "<BACKEND_STATE_BUCKET>"
    workspace_key_prefix = "<WORKSPACE_KEY_PREFIX>"
    key = "<BACKEND_STATE_FILE_KEY>"
    region = "<BACKEND_REGION>"
  }
}

provider "aws" {
  region = var.region
}

module "sa_base_support_infra" {
  source = "./modules/aws-shield-advanced-base-support-infra"

  scope_regions                  = var.scope_regions
  use_lake_formation_permissions = var.use_lake_formation_permissions
}