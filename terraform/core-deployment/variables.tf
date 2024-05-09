### sa_base_support_infra module 

variable "region" {
  type = string
}
variable "scope_regions" {
  description = "A comma separated list of AWS regions, e.g. us-east-1, us-east-2"
  type        = list(string)
}

variable "use_lake_formation_permissions" {
  type    = bool
  default = true
}

variable "target_account_id" {
  type = string
}