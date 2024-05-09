resource "aws_athena_workgroup" "athena" {
  lifecycle {
    prevent_destroy = true
  }
  name  = "oneclickshieldwaf-core-Workgroup"
  state = "ENABLED"
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.waf_logs.id}/athenaOutput"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

data "aws_lambda_invocation" "build_athena_views_call_with_lake_formation_permissions" {
  count = var.use_lake_formation_permissions ? 1 : 0
  depends_on = [
    aws_lakeformation_permissions.athena_table_lake_formation_select_permissions
  ]
  function_name = aws_lambda_function.athena_query_lambda.function_name

  input = <<-JSON
    {
      "DetailedViewQueryId": "${aws_athena_named_query.athena_named_query_ip_detailed.id}"
    }
  JSON
}

data "aws_lambda_invocation" "build_athena_views_call" {
  count = var.use_lake_formation_permissions ? 0 : 1
  depends_on = [
    aws_iam_policy.athena_query_lambda
  ]
  function_name = aws_lambda_function.athena_query_lambda.function_name

  input = <<-JSON
    {
      "DetailedViewQueryId": "${aws_athena_named_query.athena_named_query_ip_detailed.id}",
    }
  JSON
}

resource "aws_iam_role" "athena_query_lambda" {
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


resource "aws_iam_role_policy_attachment" "athena_query_lambda" {
  role       = aws_iam_role.athena_query_lambda.name
  policy_arn = aws_iam_policy.athena_query_lambda.arn
}

resource "aws_iam_policy" "athena_query_lambda" {
  name = "LocalPolicy-core"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:GetQueryExecution",
          "athena:GetNamedQuery",
          "athena:ListNamedQueries",
          "athena:StartQueryExecution"
        ]
        Resource = "arn:aws:athena:${local.aws_region_name}:${local.account_id}:workgroup/${aws_athena_workgroup.athena.name}"
      },
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
        Effect = "Allow"
        Action = [
          "glue:Get*",
          "glue:Update*",
          "glue:CreateTable"
        ]
        Resource = [
          "arn:aws:glue:${local.aws_region_name}:${local.account_id}:catalog",
          "arn:aws:glue:${local.aws_region_name}:${local.account_id}:database/default",
          "arn:aws:glue:${local.aws_region_name}:${local.account_id}:database/default/*",
          "arn:aws:glue:${local.aws_region_name}:${local.account_id}:database/oneclickshieldwaf",
          "arn:aws:glue:${local.aws_region_name}:${local.account_id}:table/oneclickshieldwaf/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:DeleteWorkGroup"
        ]
        Resource = [
          "arn:aws:athena:${local.aws_region_name}:${local.account_id}:workgroup/${aws_athena_workgroup.athena.name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:Put*",
          "s3:List*"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.waf_logs.id}/athenaOutput/*",
          "arn:aws:s3:::${aws_s3_bucket.waf_logs.id}"
        ]
      }
    ]
  })
}

data "archive_file" "athena_query_lambda" {
  type        = "zip"
  source_file = "${path.module}/code/athena_query_lambda.py"
  output_path = "athena_query_lambda.zip"
}

resource "aws_kms_key" "athena_lambda_environment" {
  lifecycle {
    prevent_destroy = true
  }
  description         = "Athena Lambda environment encryption"
  enable_key_rotation = true

}

resource "aws_lambda_function" "athena_query_lambda" {
  #checkov:skip=CKV_AWS_115:No need to set reserved concurrency
  #checkov:skip=CKV_AWS_272:Code signing not covered as part of this example.
  #checkov:skip=CKV_AWS_116:DLQ Not part of this solution example
  #checkov:skip=CKV_AWS_117:The lambda function does not need to be in a VPC for this example.
  runtime          = "python3.9"
  function_name    = "athena_create_views_query-core"
  filename         = "athena_query_lambda.zip"
  source_code_hash = data.archive_file.athena_query_lambda.output_base64sha256

  role    = aws_iam_role.athena_query_lambda.arn
  handler = "athena_query_lambda.lambda_handler"
  timeout = 300

  kms_key_arn = aws_kms_key.athena_lambda_environment.arn
  environment {
    variables = {
      s3BasePath    = "s3://${aws_s3_bucket.waf_logs.id}/athenaOutput/"
      workGroupName = aws_athena_workgroup.athena.name
      glueDatabase  = aws_glue_catalog_database.glue_waf_logs.id
    }
  }

  tracing_config {
    mode = "Active"
  }

}

resource "aws_athena_named_query" "athena_named_query_ip_detailed" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Detailed and Formatted Core RBR Data"
  name        = "waf_detailed"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT
    tz_window
    , sourceip
    , COALESCE(NULLIF(args, ''), args) args
    , COALESCE(NULLIF(httpSourceName, ''), httpSourceName) httpSourceName
    , country
    , uri
    , labels
    , accountId
    , webACLName
    , method
    , requestId
    , ntRules
    , region
    , scope
    , terminatingRuleId
    , action
    , datehour
    FROM
    (
    SELECT
      httprequest.clientip sourceip
    , httprequest.country country
    , httprequest.uri uri
    , httprequest.args args
    , httprequest.httpMethod method
    , httprequest.requestId requestId
    , httpSourceName
    , transform(filter(httprequest.headers, (x) -> x.name = 'Host'),(x) -> x.value) as domainName
    , "split_part"(webaclId, ':', 5) accountId
    , "split"("split_part"(webaclId, ':', 6), '/', 4)[4] webACLName
    , "split_part"(webaclId, ':', 4) region
    , "split"("split_part"(webaclId, ':', 6), '/', 4)[1] scope
    , webaclId
    , "array_join"("transform"(nonTerminatingMatchingRules, (x) -> x.ruleId), ',') ntRules
    , concat("transform"("filter"(labels, (x) -> (x.name LIKE 'awswaf:managed:aws:%')), (x) -> "split"(x.name, 'awswaf:managed:aws:')[2]),
              "transform"("filter"(labels, (x) -> (NOT (x.name LIKE 'awswaf%'))), (x) -> x.name)) as labels
    , terminatingRuleId
    , "from_unixtime"(("floor"((timestamp / (1000 * 300))) * 300)) tz_window
    , action
    , datehour
    FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_logs_raw"
  )
  EOF
}

resource "aws_athena_named_query" "athena_named_query_by_uriip" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Count by URI then Source IP over time."
  name        = "URIRate"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT
    count(sourceip) as count
    , tz_window
    , sourceip
    , uri
    FROM(
    SELECT *
    FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_detailed"
    )
    GROUP BY tz_window, sourceip, uri
    ORDER BY tz_window desc, count DESC"
  EOF
}

resource "aws_athena_named_query" "athena_named_query_by_country" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Count by Country then Source IP over time."
  name        = "CountryRate"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT
    count(sourceip) as count
    , tz_window
    , sourceip
    , country
    FROM (
    SELECT *
    FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_detailed"
    )
    GROUP BY tz_window, sourceip, country
    ORDER BY tz_window desc, count DESC
  EOF
}

resource "aws_athena_named_query" "athena_named_query_ip_rep" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Identify Top Client IP to specific URI path by IP"
  name        = "SourceIPReputations"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT 
    reputation,
    count(sourceip) AS count,
    sourceip,
    uri,
    tz_window
    FROM (
      SELECT sourceip,
        uri,
        tz_window,
        ntRules,
        filter (labels, (x)->(x LIKE '%IPReputationList')) as reputation
      FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_detailed"
    )
    where reputation <> array []
    GROUP BY tz_window,
      sourceip,
      uri,
      reputation
    order by reputation, count desc;
  EOF
}

resource "aws_athena_named_query" "athena_named_query_ip_anon" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Identify Top Client IP to specific URI path by IP"
  name        = "SourceIPAnonymousorHiddenOwner"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT if(anonymous = array[],
          Null,
          array_join(anonymous, ','))as anonymous,
          count(sourceip) AS count,
          sourceip,
          uri,
          tz_window
    FROM (
      SELECT sourceip,
        uri,
        tz_window,
        filter( labels, x -> x LIKE '%anonymous-ip-list%') as anonymous
      FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_detailed")
    WHERE anonymous <> array []
    GROUP BY tz_window,sourceip,uri,anonymous
    order by anonymous desc, count;
  EOF
}

resource "aws_athena_named_query" "athena_named_query_bot_control" {
  database    = aws_glue_catalog_database.glue_waf_logs.arn
  description = "Identify Bot Traffic"
  name        = "BotControlMatch"
  workgroup   = aws_athena_workgroup.athena.name
  query       = <<-EOF
    SELECT
    IF((botSignal = ARRAY[]), null, "split"(botSignal[1], 'bot-control:')[2]) botSignal,
    IF((botCategory = ARRAY[]), null, "split"(botCategory[1], 'bot-control:')[2]) botCategory,
    IF((botName = ARRAY[]), null, "split"(botName[1], 'bot-control:')[2]) botName,
    count(sourceip) as count,
    tz_window,
    sourceip,
    uri
    FROM (
      SELECT
      filter(botLabels, x -> split(x,':')[2] = 'signal') as botSignal,
      filter(botLabels, x -> split(x,':')[3] = 'category') as botCategory,
      filter(botLabels, x -> split(x,':')[3] = 'name') as botName,
      tz_window,
      sourceip,
      uri,
      datehour
      FROM (
        SELECT sourceip,
            tz_window,
            filter(labels,
            x -> x LIKE 'bot-control%') AS botLabels, action, labels, uri, datehour
        FROM "${aws_glue_catalog_database.glue_waf_logs.arn}"."waf_detailed"
      )
    WHERE botLabels <> array[]
    )
    GROUP BY tz_window, sourceip, botSignal, botCategory, botName, uri
  EOF 
}

resource "aws_lakeformation_permissions" "athena_table_lake_formation_select_permissions" {
  count     = var.use_lake_formation_permissions ? 1 : 0
  principal = aws_iam_role.athena_query_lambda.arn
  database {
    catalog_id = local.account_id
    name       = "oneclickshieldwaf"
  }
  permissions = [
    "CREATE_TABLE",
    "ALTER",
    "DESCRIBE"
  ]
  permissions_with_grant_option = [
    "CREATE_TABLE",
    "ALTER",
    "DESCRIBE"
  ]
}

resource "aws_lakeformation_permissions" "athena_table_lake_formation_permissions" {
  count     = var.use_lake_formation_permissions ? 1 : 0
  principal = aws_iam_role.athena_query_lambda.arn
  table {
    name          = aws_glue_catalog_table.glue_waf_logs.name
    catalog_id    = local.account_id
    database_name = "oneclickshieldwaf"
  }
  permissions = [
    "SELECT"
  ]
  permissions_with_grant_option = [
    "SELECT"
  ]

  depends_on = [
    data.aws_lambda_invocation.build_athena_views_call_with_lake_formation_permissions,
    data.aws_lambda_invocation.build_athena_views_call
  ]
}