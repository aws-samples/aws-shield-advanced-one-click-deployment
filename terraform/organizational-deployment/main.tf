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
  region = var.terraform_state_bucket_region
}

provider "aws" {
  alias = "target"
  region = var.target_aws_account_region
  assume_role {
    role_arn = "arn:aws:iam::${var.target_account_id}:role/OrganizationAccountAccessRole"
  }
}

data "aws_caller_identity" "current" {}

locals {
  aws_account = data.aws_caller_identity.current.account_id
  
  # Based on the target account ID and the FMS Admin account ID, certain modules are only executed within an FMS Administration account
  execute_fms_modules = var.target_account_id == var.fms_admin_account_id
}
module "sa_configure_subscribe" {
  providers = {
    aws = aws.target
  }
  source = "./modules/aws-shield-advanced-configure-subscribe"

  target_aws_account_region            = var.target_aws_account_region
  srt_access_role_name                 = var.srt_access_role_name
  srt_access_role_action               = var.srt_access_role_action
  enable_srt_access                    = var.enable_srt_access
  enable_proactive_engagement         = var.enable_proactive_engagement
  srt_buckets                          = var.srt_buckets
  acknowledge_service_terms_pricing    = var.acknowledge_service_terms_pricing
  acknowledge_service_terms_dto        = var.acknowledge_service_terms_dto
  acknowledge_service_terms_commitment = var.acknowledge_service_terms_commitment
  acknowledge_service_terms_auto_renew = var.acknowledge_service_terms_auto_renew
  acknowledge_no_unsubscribe           = var.acknowledge_no_unsubscribe
  emergency_contact_email1             = var.emergency_contact_email1
  emergency_contact_email2             = var.emergency_contact_email2
  emergency_contact_email3             = var.emergency_contact_email3
  emergency_contact_email4             = var.emergency_contact_email4
  emergency_contact_email5             = var.emergency_contact_email5
  emergency_contact_phone1             = var.emergency_contact_phone1
  emergency_contact_phone2             = var.emergency_contact_phone2
  emergency_contact_phone3             = var.emergency_contact_phone3
  emergency_contact_phone4             = var.emergency_contact_phone4
  emergency_contact_phone5             = var.emergency_contact_phone5
  emergency_contact_note1              = var.emergency_contact_note1
  emergency_contact_note2              = var.emergency_contact_note2
  emergency_contact_note3              = var.emergency_contact_note3
  emergency_contact_note4              = var.emergency_contact_note4
  emergency_contact_note5              = var.emergency_contact_note5
}

module "sa_fms_shield" {
  count = local.execute_fms_modules ? 1 : 0

  providers = {
    aws = aws.target
  }
  source = "./modules/aws-shield-advanced-fms-shield"

  scope_details                   = var.scope_details
  include_exclude_scope           = var.include_exclude_scope
  scope_type                      = var.scope_type
  resource_tag_usage              = var.resource_tag_usage
  protect_regional_resource_types = var.protect_regional_resource_types
  protect_cloud_front             = var.protect_cloud_front
  shield_auto_remediate           = var.shield_auto_remediate
  scope_tag_name1                 = var.scope_tag_name1
  scope_tag_name2                 = var.scope_tag_name2
  scope_tag_name3                 = var.scope_tag_name3
  scope_tag_value1                = var.scope_tag_value1
  scope_tag_value2                = var.scope_tag_value2
  scope_tag_value3                = var.scope_tag_value3
}

module "sa_wafv2" {
  count = local.execute_fms_modules ? 1 : 0

  providers = {
    aws = aws.target
  }
  source = "./modules/aws-shield-advanced-wafv2"

  scope_details                         = var.scope_details
  include_exclude_scope                 = var.include_exclude_scope
  scope_type                            = var.scope_type
  resource_tag_usage                    = var.resource_tag_usage
  wafv2_protect_regional_resource_types = var.wafv2_protect_regional_resource_types
  wafv2_protect_cloudfront              = var.wafv2_protect_cloudfront
  wafv2_auto_remediate                  = var.wafv2_auto_remediate
  scope_tag_name1                      = var.scope_tag_name1
  scope_tag_name2                      = var.scope_tag_name2
  scope_tag_name3                      = var.scope_tag_name3
  scope_tag_value1                     = var.scope_tag_value1
  scope_tag_value2                     = var.scope_tag_value2
  scope_tag_value3                     = var.scope_tag_value3
  rate_limit_value                      = var.rate_limit_value
  rate_limit_action                     = var.rate_limit_action
  anonymous_ip_amr_action               = var.anonymous_ip_amr_action
  ip_reputation_amr_action              = var.ip_reputation_amr_action
  core_rule_set_amr_action              = var.core_rule_set_amr_action
  known_bad_inputs_amr_actions          = var.known_bad_inputs_amr_actions
  waf_log_s3_bucket_name                = var.waf_log_s3_bucket_name
  waf_delivery_role_arn                 = var.waf_delivery_role_arn
  waf_log_kms_key_arn                   = var.waf_log_kms_key_arn
}
