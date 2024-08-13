terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  FirstEmergencyContact        = var.emergency_contact_email1 != "<na>" ? true : false
  SecondEmergencyContact       = var.emergency_contact_email2 != "<na>" ? true : false
  ThirdEmergencyContact        = var.emergency_contact_email3 != "<na>" ? true : false
  FourthEmergencyContact       = var.emergency_contact_email4 != "<na>" ? true : false
  FifthEmergencyContact        = var.emergency_contact_email5 != "<na>" ? true : false
  FirstEmergencyContactNote    = var.emergency_contact_note1 != "<na>" ? true : false
  SecondEmergencyContactNote   = var.emergency_contact_note2 != "<na>" ? true : false
  ThirdEmergencyContactNote    = var.emergency_contact_note3 != "<na>" ? true : false
  FourthEmergencyContactNote   = var.emergency_contact_note4 != "<na>" ? true : false
  FifthEmergencyContactNote    = var.emergency_contact_note5 != "<na>" ? true : false
  EnableSRTAccessCondition     = var.enable_srt_access
  SRTCreateRoleCondition       = var.srt_access_role_action == "CreateRole" ? true : false
  SRTBucketsCondition          = !(join(",", var.srt_buckets) != "<na>") ? true : false
  ProactiveEngagementCondition = var.enable_proactive_engagement ? true : false
  GenerateSRTRoleNameFlag      = var.srt_access_role_name == "<Generated>" ? true : false
  AcceptedShieldTerms = alltrue([
    "True" == var.acknowledge_service_terms_pricing,
    "True" == var.acknowledge_service_terms_dto,
    "True" == var.acknowledge_service_terms_commitment,
    "True" == var.acknowledge_service_terms_auto_renew,
    "True" == var.acknowledge_no_unsubscribe
  ])
}

resource "aws_iam_role" "shield_lambda_role" {
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
EOF
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "shield_lambda_policy" {
  role       = aws_iam_role.shield_lambda_role.name
  policy_arn = aws_iam_policy.configure_shield_lambda_policy.arn
}

resource "aws_iam_policy" "configure_shield_lambda_policy" {
  name = "ConfigureShieldLambdaPolicy-${var.target_aws_account_region}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "ShieldSubscription"
        Effect = "Allow"
        Action = [
          "shield:CreateSubscription",
          "shield:UpdateSubscription",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "configure_shield_lambda" {
  type        = "zip"
  source_file = "${path.module}/code/configure_shield.py"
  output_path = "configure_shield_lambda.zip"
}

resource "aws_lambda_function" "configure_shield_lambda" {
  #checkov:skip=CKV_AWS_115:No need to set reserved concurrency
  #checkov:skip=CKV_AWS_272:Code signing not covered as part of this example.
  #checkov:skip=CKV_AWS_116:DLQ Not part of this solution example
  #checkov:skip=CKV_AWS_117:The lambda function does not need to be in a VPC for this example.
  function_name    = "configure_shield"
  filename         = data.archive_file.configure_shield_lambda.output_path
  source_code_hash = data.archive_file.configure_shield_lambda.output_base64sha256
  tracing_config {
    mode = "Active"
  }

  runtime = "python3.12"
  timeout = 15
  role    = aws_iam_role.shield_lambda_role.arn
  handler = "configure_shield.lambda_handler"

}

data "aws_lambda_invocation" "configure_shield_lambda" {
  function_name = aws_lambda_function.configure_shield_lambda.function_name

  input = <<-JSON
    { 
      "RequestType": "Create"
    }
  JSON

  depends_on = [
    aws_lambda_function.configure_shield_lambda
  ]
}

resource "aws_iam_role" "srt_access_role" {
  count = local.SRTCreateRoleCondition ? 1 : 0
  name  = local.GenerateSRTRoleNameFlag ? null : var.srt_access_role_name
  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"
  ]
  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "drt.shield.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
    EOF
}

locals {
  srt_access_role_arn = local.GenerateSRTRoleNameFlag ? "${aws_iam_role.srt_access_role[0].arn}" : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.srt_access_role_name}"
}

resource "aws_shield_drt_access_role_arn_association" "enable_srt_access" {
  count = local.EnableSRTAccessCondition ? 1 : 0

  role_arn = local.srt_access_role_arn
}

resource "aws_shield_drt_access_log_bucket_association" "enable_srt_access" {
  for_each = local.EnableSRTAccessCondition ? toset(var.srt_buckets) : toset([])

  log_bucket              = each.key
  role_arn_association_id = aws_shield_drt_access_role_arn_association.enable_srt_access[0].role_arn
}

resource "aws_shield_proactive_engagement" "proactive_engagement" {
  count = local.ProactiveEngagementCondition ? 1 : 0

  enabled = true
  
  dynamic "emergency_contact" {
    for_each = local.FirstEmergencyContact ? [1] : []
    content {
      email_address = var.emergency_contact_email1
      phone_number  = var.emergency_contact_phone1
      contact_notes = var.emergency_contact_note1
    }
  }

  dynamic "emergency_contact" {
    for_each = local.SecondEmergencyContact ? [1] : []
    content {
      email_address = var.emergency_contact_email2
      phone_number  = var.emergency_contact_phone2
      contact_notes = var.emergency_contact_note2
    }
  }

  dynamic "emergency_contact" {
    for_each = local.ThirdEmergencyContact ? [1] : []
    content {
      email_address = var.emergency_contact_email3
      phone_number  = var.emergency_contact_phone3
      contact_notes = var.emergency_contact_note3
    }
  }

  dynamic "emergency_contact" {
    for_each = local.FourthEmergencyContact ? [1] : []
    content {
      email_address = var.emergency_contact_email4
      phone_number  = var.emergency_contact_phone4
      contact_notes = var.emergency_contact_note4
    }
  }

  dynamic "emergency_contact" {
    for_each = local.FifthEmergencyContact ? [1] : []
    content {
      email_address = var.emergency_contact_email5
      phone_number  = var.emergency_contact_phone5
      contact_notes = var.emergency_contact_note5
    }
  
  }
}