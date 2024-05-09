variable "scope_regions" {
  description = "A comma separated list of AWS regions, e.g. us-east-1, us-east-2"
  type        = list(string)
}

variable "use_lake_formation_permissions" {
  type    = bool
  default = true
  description = "Determines whether Athena is configured to utlize lake formation."
}