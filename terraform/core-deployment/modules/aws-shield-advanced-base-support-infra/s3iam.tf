resource "aws_s3_bucket" "logging" {
  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "logging" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.logging.arn,
      "${aws_s3_bucket.logging.arn}/*"
    ]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceARN"
      values   = [aws_s3_bucket.waf_logs.arn]
    }
  }
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.logging.arn,
      "${aws_s3_bucket.logging.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

  }
}

resource "aws_s3_bucket_policy" "logging" {
  bucket = aws_s3_bucket.logging.id
  policy = data.aws_iam_policy_document.logging.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket" "waf_logs" {
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.waf_logs.arn
    }
  }
}

resource "aws_kms_key" "waf_logs" {
  lifecycle {
    prevent_destroy = true
  }
  description         = "WAF Log Key"
  enable_key_rotation = true

}

resource "aws_kms_key_policy" "waf_logs" {
  key_id = aws_kms_key.waf_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM UserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "waf_logs" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["${local.account_id}"]
    }
  }
}

resource "aws_iam_role" "waf_logs" {
  assume_role_policy = data.aws_iam_policy_document.waf_logs.json
}

resource "aws_iam_role_policy_attachment" "waf_logs" {
  role       = aws_iam_role.waf_logs.name
  policy_arn = aws_iam_policy.waf_delivery.arn
}

data "aws_iam_policy_document" "waf_delivery" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [
      aws_kms_key.waf_logs.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${local.aws_region_name}.amazonaws"
      ]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values = [
        "arn:aws:s3:::${aws_s3_bucket.waf_logs.arn}/*",
        "arn:aws:s3:::${aws_s3_bucket.logging.arn}/*"
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.waf_logs.arn}",
      "arn:aws:s3:::${aws_s3_bucket.waf_logs.arn}/*",
      "arn:aws:s3:::${aws_s3_bucket.logging.arn}",
      "arn:aws:s3:::${aws_s3_bucket.logging.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${local.aws_region_name}:${local.aws_region_name}:log-group:/aws/kinesisfirehose:log-stream:aws-waf-logs-delivery-${local.account_id}-${local.aws_region_name}}"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${local.aws_region_name}:${local.aws_region_name}:log-group:/aws/kinesisfirehose:log-stream:aws-waf-logs-delivery-${local.account_id}-${local.aws_region_name}}"
    ]
  }
}

resource "aws_iam_policy" "waf_delivery" {
  name   = "firehose_delivery_policy-core"
  policy = data.aws_iam_policy_document.waf_delivery.json
}
