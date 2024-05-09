terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

}

data "aws_region" "current" {}

locals {
  workspace_name = terraform.workspace
  ScopeTagName1Flag = var.scope_tag_name1 != "<na>"
  ScopeTagName2Flag = var.scope_tag_name2 != "<na>"
  ScopeTagName3Flag = var.scope_tag_name3 != "<na>"
  ScopeTagValue1Flag = var.scope_tag_value1 != "<na>"
  ScopeTagValue2Flag = var.scope_tag_value2 != "<na>"
  ScopeTagValue3Flag = var.scope_tag_value3 != "<na>"
  ShieldAutoRemediateFlag = var.shield_auto_remediate != "No"
  OUScopeFlag = var.scope_type == "OU"
  AccountScopeFlag = var.scope_type == "Accounts"
  ExcludeResourceTagFlag = var.resource_tag_usage == "Exclude"
  IncludeScopeFlag = var.include_exclude_scope == "Include"
  ExcludeScopeFlag = var.include_exclude_scope == "Exclude"
  CreateRegionalPolicyFlag = length(var.protect_regional_resource_types) > 0
  CreateCloudFrontPolicyFlag = alltrue([
    var.protect_cloud_front != "<na>",
    data.aws_region.current.name == "us-east-1"
  ])
  stack_name = "fms-shield"

  resource_tags = {
    
  }
}

resource "aws_fms_policy" "shield_regional_resources" {
  count = local.CreateRegionalPolicyFlag ? 1 : 0
  name = "OneClickShieldRegional-${local.workspace_name}"
  //resource_type = length(var.protect_regional_resource_types) == 1 ? element(var.protect_regional_resource_types, 0) : ""
  resource_type_list = var.protect_regional_resource_types
  //resource_type_list = length(var.protect_regional_resource_types) > 1 ? var.protect_regional_resource_types : null
  exclude_resource_tags = local.ExcludeResourceTagFlag

  security_service_policy_data {
    type = "SHIELD_ADVANCED"

    managed_service_data = jsonencode({ type = "SHIELD_ADVANCED" })
  } 
  
  dynamic include_map {
    for_each = local.IncludeScopeFlag && length(var.scope_details) > 0 ? [1] : []
    content {
      account = local.AccountScopeFlag ? var.scope_details : null
      orgunit = local.OUScopeFlag ? var.scope_details : null 
    }
  }

  dynamic exclude_map {
    for_each = local.ExcludeScopeFlag && length(var.scope_details) > 0 ? [1] : []
    content {
      account = local.AccountScopeFlag ? var.scope_details : null
      orgunit = local.OUScopeFlag ? var.scope_details : null 
    }
  }

  remediation_enabled = local.ShieldAutoRemediateFlag
  delete_all_policy_resources = false
  resource_tags = local.ScopeTagName1Flag ? tomap([
    local.ScopeTagName1Flag ? {
      "Key"   = var.scope_tag_name1,
      "Value" = local.ScopeTagName1Flag ? var.scope_tag_value1 : ""
    } : null,
    local.ScopeTagName2Flag ? {
      "Key"   = var.scope_tag_name2
      "Value" = local.ScopeTagName2Flag ? var.scope_tag_value2 : ""
    } : null,
    local.ScopeTagName3Flag ? {
      Key   = var.scope_tag_name3
      Value = local.ScopeTagName3Flag ? var.scope_tag_value3 : ""
  } : null]) : null
}

