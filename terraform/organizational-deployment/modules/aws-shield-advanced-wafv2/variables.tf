variable scope_details {
  type    = list(string)
  default = []
}

variable "include_exclude_scope" {
  type    = string
  default = "Include"
  validation {
    condition     = contains(["Include", "Exclude"], var.include_exclude_scope)
    error_message = "Allowed values are [ Include | Exclude ]"
  }
}

variable "scope_type" {
  description = "Should Firewall Manager Policies be scoped to the entire org (root) or a specific list of OUs (OU)"
  type        = string
  default     = "Org"
  validation {
    condition     = contains(["Org", "OU", "Accounts"], var.scope_type)
    error_message = "Allowed values are [ Org | OU | Accounts ]"
  }
}

variable "resource_tag_usage" {
  description = "Include will scope to only include when ResourceTags match, Exclude will exclude when target resource tags match ResourceTags"
  type        = string
  default     = "Include"
  validation {
    condition     = contains(["Include", "Exclude"], var.resource_tag_usage)
    error_message = "Allowed values are [ Include | Exclude ]"
  }
}

variable "wafv2_protect_regional_resource_types" {
  type    = string
  default = "AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer"
  validation {
    condition     = contains(["AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer", "AWS::ElasticLoadBalancingV2::LoadBalancer", "AWS::ApiGateway::Stage", "<na>"], var.wafv2_protect_regional_resource_types)
    error_message = "Allowed values are [ AWS::ApiGateway::Stage,AWS::ElasticLoadBalancingV2::LoadBalancer | AWS::ElasticLoadBalancingV2::LoadBalancer | AWS::ApiGateway::Stage | <na> ]"
  }
}

variable "wafv2_protect_cloudfront" {
  type    = string
  default = "<na>"
  validation {
    condition     = contains(["AWS::CloudFront::Distribution", "<na>"], var.wafv2_protect_cloudfront)
    error_message = "Allowed values are [ AWS::CloudFront::Distribution | <na> ]"
  }
}

variable "wafv2_auto_remediate" {
  description = "Should in scope AWS resource types that support AWS WAF automatically be remediated?"
  type        = string
  validation {
    condition     = contains(["Yes | Replace existing exsiting WebACL", "Yes | If no current WebACL", "No"], var.wafv2_auto_remediate)
    error_message = "Allowed values are [ 'Yes | Replace existing exsiting WebACL' | 'Yes | If no current WebACL' | 'No']"
  }
}

variable "scope_tag_name1" {
  type    = string
  default = "<na>"
}

variable "scope_tag_name2" {
  type    = string
  default = "<na>"
}

variable "scope_tag_name3" {
  type    = string
  default = "<na>"
}

variable "scope_tag_value1" {
  type    = string
  default = "<na>"
}

variable "scope_tag_value2" {
  type    = string
  default = "<na>"
}

variable "scope_tag_value3" {
  type    = string
  default = "<na>"
}

variable "rate_limit_value" {
  description = "AWS WAF rate limits use the previous 5 minutes to determine if an IP has exceeded the defined limit."
  type        = string
  default     = 10000
}

variable "rate_limit_action" {
  type    = string
  default = "Block"
  validation {
    condition     = contains(["Block", "Count"], var.rate_limit_action)
    error_message = "Allowed values are [ Block | Count ]"
  }
}

variable "anonymous_ip_amr_action" {
  description = "The Anonymous IP list rule group contains rules to block requests from services that permit the obfuscation of viewer identity. These include requests from VPNs, proxies, Tor nodes, and hosting providers. This rule group is useful if you want to filter out viewers that might be trying to hide their identity from your application."
  type        = string
  default     = "Block"
  validation {
    condition     = contains(["Block", "Count"], var.anonymous_ip_amr_action)
    error_message = "Allowed values are [ Block | Count ]"
  }
}

variable "ip_reputation_amr_action" {
  description = "The Amazon IP reputation list rule group contains rules that are based on Amazon internal threat intelligence. This is useful if you would like to block IP addresses typically associated with bots or other threats. Blocking these IP addresses can help mitigate bots and reduce the risk of a malicious actor discovering a vulnerable application."
  type        = string
  default     = "Block"
  validation {
    condition     = contains(["Block", "Count"], var.ip_reputation_amr_action)
    error_message = "Allowed values are [ Block | Count ]"
  }
}

variable "core_rule_set_amr_action" {
  description = "The Core rule set (CRS) rule group contains rules that are generally applicable to web applications. This provides protection against exploitation of a wide range of vulnerabilities, including some of the high risk and commonly occurring vulnerabilities described in OWASP publications such as OWASP Top 10"
  type        = string
  default     = "Count"
  validation {
    condition     = contains(["Block", "Count"], var.core_rule_set_amr_action)
    error_message = "Allowed values are [ Block | Count ]"
  }
}

variable "known_bad_inputs_amr_actions" {
  description = "The Known bad inputs rule group contains rules to block request patterns that are known to be invalid and are associated with exploitation or discovery of vulnerabilities. This can help reduce the risk of a malicious actor discovering a vulnerable application."
  type        = string
  default     = "Count"
  validation {
    condition     = contains(["Block", "Count"], var.known_bad_inputs_amr_actions)
    error_message = "Allowed values are [ Block | Count ]"
  }
}

variable "waf_log_s3_bucket_name" {
  type = string
}

variable "waf_delivery_role_arn" {
  type = string
}

variable "waf_log_kms_key_arn" {
  type = string
}