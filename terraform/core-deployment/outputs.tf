output "waf_log_s3_bucket_name" {
  value = module.sa_base_support_infra.waf_log_s3_bucket_name
}

output "waf_log_kms_key_arn" {
  value = module.sa_base_support_infra.waf_log_kms_key_arn
}

output "waf_delivery_role_arn" {
  value = module.sa_base_support_infra.waf_delivery_role_arn
}

output "primary_region" {
  value = var.region
}

output "scope_regions" {
  value = "${join(",",var.scope_regions)}"
}
