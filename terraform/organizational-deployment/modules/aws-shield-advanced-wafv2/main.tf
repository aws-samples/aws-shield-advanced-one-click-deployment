terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  workspace_name              = terraform.workspace
  aws_region                  = data.aws_region.current.name
  aws_account                 = data.aws_caller_identity.current.account_id
  ScopeTagName1Flag           = var.scope_tag_name1 != "<na>" ? true : false
  ScopeTagName2Flag           = var.scope_tag_name2 != "<na>" ? true : false
  ScopeTagName3Flag           = var.scope_tag_name3 != "<na>" ? true : false
  ScopeTagValue1Flag          = var.scope_tag_value1 != "<na>" ? true : false
  ScopeTagValue2Flag          = var.scope_tag_value2 != "<na>" ? true : false
  ScopeTagValue3Flag          = var.scope_tag_value3 != "<na>" ? true : false
  AutoRemediateForceFlag      = var.wafv2_auto_remediate == "Yes | Replace existing exsiting WebACL" ? true : false
  AutoRemediateFlag           = var.wafv2_auto_remediate == "Yes | If no current WebACL" || var.wafv2_auto_remediate == "Yes | Replace existing exsiting WebACL" ? true : false
  OUScopeFlag                 = var.scope_type == "OU" ? true : false
  AccountScopeFlag            = var.scope_type == "Accounts" ? true : false
  ExcludeResourceTagFlag      = var.resource_tag_usage == "Exclude" ? true : false
  IncludeScopeFlag            = var.include_exclude_scope == "Include" ? true : false
  ExcludeScopeFlag            = var.include_exclude_scope == "Exclude" ? true : false
  CreateRegionalPolicyFlag    = var.wafv2_protect_regional_resource_types != "<na>" ? true : false
  CreateCloudFrontPolicyFlag  = var.wafv2_protect_cloudfront != "<na>" && data.aws_region.current.name == "us-east-1" ? true : false
  RateLimitActionFlag         = var.rate_limit_action == "Block" ? true : false
  AnonymousIPAMRActionFlag    = var.anonymous_ip_amr_action == "Block" ? true : false
  IPReputationAMRActionFlag   = var.ip_reputation_amr_action == "Block" ? true : false
  CoreRuleSetAMRActionFlag    = var.core_rule_set_amr_action == "Block" ? true : false
  KnownBadInputsAMRActionFlag = var.known_bad_inputs_amr_actions == "Block" ? true : false
}

locals {
  IPReputationActionValue   = local.IPReputationAMRActionFlag == true ? "NONE" : "COUNT"
  AnonymousIPActionValue    = local.AnonymousIPAMRActionFlag == true ? "NONE" : "COUNT"
  KnownBadInputsActionValue = local.KnownBadInputsAMRActionFlag == true ? "NONE" : "COUNT"
  CoreRuleSetActionValue    = local.CoreRuleSetAMRActionFlag == true ? "NONE" : "COUNT"
  AutoRemediateForceValue   = local.AutoRemediateForceFlag == true ? true : false

}

resource "aws_fms_policy" "regional_wafv2_security_policy" {
  count = local.CreateRegionalPolicyFlag ? 1 : 0

  name                  = "OneClickShieldRegional-${local.workspace_name}"
  resource_type_list    = split(",", var.wafv2_protect_regional_resource_types)
  exclude_resource_tags = local.ExcludeResourceTagFlag ? true : false
  include_map {
    orgunit = local.IncludeScopeFlag ? (local.OUScopeFlag ? var.scope_details : null) : null
    account = local.IncludeScopeFlag ? (local.AccountScopeFlag ? var.scope_details : null) : null
  }
  exclude_map {
    orgunit = local.ExcludeScopeFlag ? (local.OUScopeFlag ? var.scope_details : null) : null
    account = local.ExcludeScopeFlag ? (local.AccountScopeFlag ? var.scope_details : null) : null
  }
  remediation_enabled         = local.AutoRemediateFlag ? true : false
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

  security_service_policy_data {
    type = "WAFV2"

    managed_service_data = jsonencode({
      type = "WAFV2",
      preProcessRuleGroups = [
        {
          ruleGroupArn = "${aws_wafv2_rule_group.regional_rate_limit_rule_group[0].arn}",
          overrideAction = {
            type = "NONE"
          },
          ruleGroupType          = "RuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesAmazonIpReputationList"
          },
          overrideAction = {
            type = "${local.IPReputationActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesAnonymousIpList"
          },
          overrideAction = {
            type = "${local.AnonymousIPActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesKnownBadInputsRuleSet"
          },
          overrideAction = {
            type = "${local.KnownBadInputsActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesCommonRuleSet"
          },
          overrideAction = {
            type = "${local.CoreRuleSetActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        }
      ],
      postProcessRuleGroups = [],
      defaultAction = {
        type = "ALLOW"
      },
      overrideCustomerWebACLAssociation       = "${local.AutoRemediateForceValue}",
      sampledRequestsEnabledForDefaultActions = true,
      loggingConfiguration = {
        redactedFields = [],
        logDestinationConfigs = [
          "${aws_kinesis_firehose_delivery_stream.waf_delivery_stream.arn}"
        ]
      }
    })
  }
}

resource "aws_fms_policy" "cloudfront_wafv2_security_policy" {
  count = local.CreateCloudFrontPolicyFlag ? 1 : 0

  name                  = "OneClickShieldGlobal-${local.workspace_name}"
  resource_type         = "AWS::CloudFront::Distribution"
  exclude_resource_tags = local.ExcludeResourceTagFlag ? true : false
  include_map {
    account = local.IncludeScopeFlag ? (local.OUScopeFlag ? var.scope_details : null) : null
    orgunit = local.IncludeScopeFlag ? (local.AccountScopeFlag ? var.scope_details : null) : null
  }
  exclude_map {
    account = local.ExcludeScopeFlag ? (local.OUScopeFlag ? var.scope_details : null) : null
    orgunit = local.ExcludeScopeFlag ? (local.AccountScopeFlag ? var.scope_details : null) : null
  }
  remediation_enabled         = local.AutoRemediateFlag ? true : false
  delete_all_policy_resources = false
  resource_tags = local.ScopeTagName1Flag ? tomap([
    local.ScopeTagName1Flag ? {
      Key   = var.scope_tag_name1,
      Value = local.ScopeTagName1Flag ? var.scope_tag_value1 : ""
    } : null,
    local.ScopeTagName2Flag ? {
      Key   = var.scope_tag_name2
      Value = local.ScopeTagName2Flag ? var.scope_tag_value2 : ""
    } : null,
    local.ScopeTagName3Flag ? {
      Key   = var.scope_tag_name3
      Value = local.ScopeTagName3Flag ? var.scope_tag_value3 : ""
  } : null]) : null

  security_service_policy_data {
    type = "WAFV2"

    managed_service_data = jsonencode({
      type = "WAFV2",
      preProcessRuleGroups = [
        {
          ruleGroupArn = "${aws_wafv2_rule_group.cloudfront_rate_limit_rule_group[0].arn}",
          overrideAction = {
            type = "NONE"
          },
          ruleGroupType          = "RuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesAmazonIpReputationList"
          },
          overrideAction = {
            type = "${local.IPReputationActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesAnonymousIpList"
          },
          overrideAction = {
            type = "${local.AnonymousIPActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesKnownBadInputsRuleSet"
          },
          overrideAction = {
            type = "${local.KnownBadInputsActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        },
        {
          managedRuleGroupIdentifier = {
            vendorName           = "AWS",
            managedRuleGroupName = "AWSManagedRulesCommonRuleSet"
          },
          overrideAction = {
            type = "${local.CoreRuleSetActionValue}"
          },
          ruleGroupType          = "ManagedRuleGroup",
          excludeRules           = [],
          sampledRequestsEnabled = true
        }
      ],
      postProcessRuleGroups = [],
      defaultAction = {
        type = "ALLOW"
      },
      overrideCustomerWebACLAssociation       = "${local.AutoRemediateForceValue}",
      sampledRequestsEnabledForDefaultActions = true,
      loggingConfiguration = {
        redactedFields = [],
        logDestinationConfigs = [
          "${aws_kinesis_firehose_delivery_stream.waf_delivery_stream.arn}"
        ]
      }
    })
  }
}

resource "aws_wafv2_rule_group" "regional_rate_limit_rule_group" {
  count = local.CreateRegionalPolicyFlag ? 1 : 0

  name        = "OneClickDeployRuleGroup-${local.workspace_name}"
  description = "OneClickDeployRuleGroup-${local.workspace_name}"
  scope       = "REGIONAL"
  capacity    = 10
  rule {
    name     = "RateLimit"
    priority = 0
    dynamic "action" {
      for_each = local.RateLimitActionFlag == true ? [1] : []
      content {
        block {}
      }
    }
    dynamic "action" {
      for_each = local.RateLimitActionFlag != true ? [1] : []
      content {
        count {}
      }
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_value
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "OneClickDeployRuleGroup-${local.workspace_name}"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_rule_group" "cloudfront_rate_limit_rule_group" {
  count = local.CreateCloudFrontPolicyFlag ? 1 : 0

  name        = "OneClickDeployRuleGroup-${local.workspace_name}"
  description = "OneClickDeployRuleGroup-${local.workspace_name}"
  scope       = "CLOUDFRONT"
  capacity    = 10
  rule {
    name     = "RateLimit"
    priority = 0
    dynamic "action" {
      for_each = local.RateLimitActionFlag == true ? [1] : []
      content {
        block {}
      }
    }
    dynamic "action" {
      for_each = local.RateLimitActionFlag != true ? [1] : []
      content {
        count {}
      }
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_value
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "OneClickDeployRuleGroup-${local.workspace_name}"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudwatch_log_group" "waf_delivery_log_group" {
  name              = "/aws/kinesisfirehose/${local.workspace_name}"
  kms_key_id        = aws_kms_key.kms_key.arn
  retention_in_days = 365

  depends_on = [aws_kms_key.kms_key]
}

resource "aws_cloudwatch_log_stream" "waf_delivery_log_stream" {
  name           = "aws-waf-logs-${local.workspace_name}-${local.aws_region}"
  log_group_name = "/aws/kinesisfirehose/${local.workspace_name}"
}

resource "aws_kinesis_firehose_delivery_stream" "waf_delivery_stream" {
  name        = "aws-waf-logs-${local.workspace_name}-${local.aws_region}"
  destination = "extended_s3"

  server_side_encryption {
    enabled = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn = var.waf_log_kms_key_arn
  }

  extended_s3_configuration {
    role_arn   = var.waf_delivery_role_arn
    bucket_arn = "arn:aws:s3:::${var.waf_log_s3_bucket_name}"
    prefix     = "firehose/${local.aws_region}/}"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${local.workspace_name}"
      log_stream_name = "aws-waf-logs-${local.workspace_name}-${local.aws_region}"

    }

    buffering_size     = 50
    buffering_interval = 60
    compression_format = "UNCOMPRESSED"
    kms_key_arn        = var.waf_log_kms_key_arn
  }
}

resource "aws_kms_key" "kms_key" {
  description             = "CloudWatch Log Encryption Key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
}

resource "aws_kms_key_policy" "kms_key" {
  key_id = aws_kms_key.kms_key.id
  policy = jsonencode({
    Id = "key-default-1"
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.aws_account}:root"
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
      {
        Action = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.aws_region}.amazonaws.com"
        }
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${local.aws_region}:${local.aws_account}:log-group:/aws/kinesisfirehose/${local.workspace_name}"
          }
        }
        Resource = "*"
        Sid      = "Allow administration of the key"
      }
    ]
    Version = "2012-10-17"
  })
}