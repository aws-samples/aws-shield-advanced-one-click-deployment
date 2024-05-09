resource "aws_glue_catalog_database" "glue_waf_logs" {
  catalog_id   = local.account_id
  name         = "oneclickshieldwaf-core"
  location_uri = "s3://${aws_s3_bucket.waf_logs.id}/${local.aws_region_name}"
}

resource "aws_glue_catalog_table" "glue_waf_logs" {
  catalog_id    = local.account_id
  database_name = aws_glue_catalog_database.glue_waf_logs.name
  name          = "waf_logs_raw"
  table_type    = "EXTERNAL_TABLE"
  partition_keys {
    name = "datehour"
    type = "string"
  }
  partition_keys {
    name = "region"
    type = "string"
  }

  parameters = {
    EXTERNAL                            = "TRUE"
    "projection.region.type"            = "enum"
    "projection.region.values"          = "${join(",", var.scope_regions)}"
    "projection.datehour.format"        = "yyyy/MM/dd/HH"
    "projection.datehour.interval"      = "1"
    "projection.datehour.interval.unit" = "HOURS"
    "projection.datehour.range"         = "2023/06/01/00,NOW"
    "projection.datehour.type"          = "date"
    "projection.enabled"                = "true"
    "storage.location.template"         = "s3://${aws_s3_bucket.waf_logs.id}/firehose/$${region}/$${datehour}"
  }

  storage_descriptor {
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    location      = "s3://${aws_s3_bucket.waf_logs.id}/firehose/"
    ser_de_info {
      parameters = {
        "serialization.format" = "1"
      }
    }
    columns {
      name = "timestamp"
      type = "bigint"
    }

    columns {
      name = "formatversion"
      type = "int"
    }
    columns {
      name = "webaclid"
      type = "string"
    }
    columns {
      name = "terminatingruleid"
      type = "string"
    }
    columns {
      name = "terminatingruletype"
      type = "string"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "terminatingrulematchdetails"
      type = "array<struct<conditiontype:string,location:string,matcheddata:array<string>>>"
    }
    columns {
      name = "httpsourcename"
      type = "string"
    }
    columns {
      name = "httpsourceid"
      type = "string"
    }
    columns {
      name = "rulegrouplist"
      type = "array<struct<rulegroupid:string,terminatingrule:struct<ruleid:string,action:string,rulematchdetails:string>,nonterminatingmatchingrules:array<struct<ruleid:string,action:string,rulematchdetails:array<struct<conditiontype:string,location:string,matcheddata:array<string>>>>>,excludedrules:array<struct<ruleid:string,exclusiontype:string>>>>"
    }
    columns {
      name = "ratebasedrulelist"
      type = "array<struct<ratebasedruleid:string,limitkey:string,maxrateallowed:int>>"
    }
    columns {
      name = "nonterminatingmatchingrules"
      type = "array<struct<ruleid:string,action:string>>"
    }
    columns {
      name = "requestheadersinserted"
      type = "string"
    }
    columns {
      name = "responsecodesent"
      type = "string"
    }
    columns {
      name = "httprequest"
      type = "struct<clientip:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpversion:string,httpmethod:string,requestid:string>"
    }
    columns {
      name = "labels"
      type = "array<struct<name:string>>"
    }
  }
}

output "glue_waf_logs" {
  value = aws_glue_catalog_database.glue_waf_logs.id
}