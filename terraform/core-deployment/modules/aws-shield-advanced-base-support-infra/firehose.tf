locals {
  workspace_name = terraform.workspace
}

resource "aws_cloudwatch_log_group" "waf_delivery_log_group" {
  name              = "/aws/kinesisfirehose/${local.workspace_name}"
  kms_key_id        = aws_kms_key.waf_delivery_log_key.arn
  retention_in_days = 365

  depends_on = [aws_kms_key.waf_delivery_log_key]
}

resource "aws_cloudwatch_log_stream" "waf_delivery_log_stream" {
  name           = "WAFDeliveryLogStram"
  log_group_name = "/aws/kinesisfirehose/${local.workspace_name}"
}

resource "aws_kinesis_firehose_delivery_stream" "waf_delivery_stream" {
  name        = "aws-waf-logs-${local.workspace_name}-${local.aws_region_name}"
  destination = "extended_s3"

  server_side_encryption {
    enabled = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn = aws_kms_key.waf_delivery_log_key.arn
  }

  extended_s3_configuration {
    bucket_arn = aws_s3_bucket.waf_logs.arn
    role_arn   = aws_iam_role.waf_logs.arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${local.workspace_name}"
      log_stream_name = aws_cloudwatch_log_stream.waf_delivery_log_stream.name
    }
    buffering_interval = 60
    buffering_size     = 50
    compression_format = "UNCOMPRESSED"
    prefix             = "firehose/${local.aws_region_name}"

    kms_key_arn = aws_kms_key.waf_delivery_log_key.arn
  }
}

resource "aws_kms_key" "waf_delivery_log_key" {
  description             = "CloudWatch Log Encryption Key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy                  = <<-EOF
  {
    "Version": "2012-10-17",
    "Id": "key-default-1",
    "Statement": [
      {
        "Sid": "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.account_id}:root"
        },
        "Action"   : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid"    : "Allow administration of the key",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "logs.${local.aws_region_name}.amazonaws.com"
        },
        "Action" : [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        "Resource" : "*"
       
      }
    ]
  }
  EOF
}