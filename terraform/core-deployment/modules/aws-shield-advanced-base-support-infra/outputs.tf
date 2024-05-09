output "waf_log_s3_bucket_name" {
  value = aws_s3_bucket.waf_logs.id
}

output "waf_log_kms_key_arn" {
  value = aws_kms_key.waf_logs.arn
}

output "waf_delivery_role_arn" {
  value = aws_iam_role.waf_logs.arn
}
