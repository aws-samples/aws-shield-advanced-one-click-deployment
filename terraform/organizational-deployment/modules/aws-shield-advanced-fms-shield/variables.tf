variable "scope_details" {
  type    = list(string)
  default = []
}

variable "include_exclude_scope" {
  type    = string
  default = "Include"
}

variable "scope_type" {
  description = "Should Firewall Manager Policies be scoped to the entire org (root) or a specific list of OUs (OU)"
  type        = string
  default     = "Org"
  validation {
    condition     = contains(["Org", "OU", "Accounts"], var.scope_type)
    error_message = "scope_type must be one of [ Org | OU | Accounts ]"
  }
}

variable "resource_tag_usage" {
  description = "Include will scope to only include when ResourceTags match, Exclude will exclude when target resource tags match ResourceTags"
  type        = string
  default     = "Include"
}

variable "protect_regional_resource_types" {
  description = "AWS::ElasticLoadBalancingV2::LoadBalancer,AWS::ElasticLoadBalancing::LoadBalancer,AWS::EC2::EIP"
  type        = list(string)
  default     = ["AWS::ElasticLoadBalancingV2::LoadBalancer","AWS::ElasticLoadBalancing::LoadBalancer","AWS::EC2::EIP"]
}

variable "protect_cloud_front" {
  type    = string
  default = "<na>"
}

variable "shield_auto_remediate" {
  description = "Should in scope AWS resource types have Shield Advanced protection automatically be remediated?"
  type        = string
  default     = "Yes"
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