resource "aws_glue_catalog_database" "etl_db" {
  name = var.glue_db_name
}

resource "aws_glue_catalog_table" "weather_data" {
  database_name = aws_glue_catalog_database.etl_db.name
  name          = "weather_data_parquet"
  
  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.data_bucket-final-papas412.bucket}/parquet-data/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "my-stream"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "ghi"
      type = "double"
    }
    columns {
      name = "dhi"
      type = "double"
    }
    columns {
      name = "precip"
      type = "double"
    }
    columns {
      name = "timestamp_utc"
      type = "string"
    }
    columns {
      name = "temp"
      type = "double"
    }
    columns {
      name = "app_temp"
      type = "double"
    }
    columns {
      name = "dni"
      type = "double"
    }
    columns {
      name = "snow_depth"
      type = "double"
    }
    columns {
      name = "wind_cdir"
      type = "string"
    }
    columns {
      name = "rh"
      type = "double"
    }
    columns {
      name = "pod"
      type = "string"
    }
    columns {
      name = "pop"
      type = "double"
    }
    columns {
      name = "ozone"
      type = "double"
    }
    columns {
      name = "clouds_hi"
      type = "int"
    }
    columns {
      name = "clouds"
      type = "int"
    }
    columns {
      name = "vis"
      type = "double"
    }
    columns {
      name = "wind_spd"
      type = "double"
    }
    columns {
      name = "wind_cdir_full"
      type = "string"
    }
    columns {
      name = "slp"
      type = "double"
    }
    columns {
      name = "datetime"
      type = "string"
    }
    columns {
      name = "ts"
      type = "bigint"
    }
    columns {
      name = "pres"
      type = "double"
    }
    columns {
      name = "dewpt"
      type = "double"
    }
    columns {
      name = "uv"
      type = "double"
    }
    columns {
      name = "clouds_mid"
      type = "int"
    }
    columns {
      name = "wind_dir"
      type = "int"
    }
    columns {
      name = "snow"
      type = "double"
    }
    columns {
      name = "clouds_low"
      type = "int"
    }
    columns {
      name = "solar_rad"
      type = "double"
    }
    columns {
      name = "wind_gust_spd"
      type = "double"
    }
    columns {
      name = "timestamp_local"
      type = "string"
    }
    columns {
      name = "description"
      type = "string"
    }
    columns {
      name = "code"
      type = "string"
    }
  }
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_s3_glue_policy" {
  name   = "firehose_s3_glue_policy"
  role   = aws_iam_role.firehose_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.data_bucket-final-papas412.arn,
          "${aws_s3_bucket.data_bucket-final-papas412.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetTableVersion",
          "glue:GetTableVersions"
        ]
        Resource = [
          "arn:aws:glue:*:*:catalog",
          aws_glue_catalog_database.etl_db.arn,
          aws_glue_catalog_table.weather_data.arn
        ]
      },
      {
          Effect = "Allow",
          Action = [
              "logs:PutLogEvents"
          ],
          Resource = [
              "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/*"
          ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "weather_stream" {
  name        = "weather-data-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.data_bucket-final-papas412.arn
    
    # Required for data format conversion (min 64MB)
    buffer_size     = 128
    buffer_interval = 300

    prefix              = "parquet-data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "firehose-failures/!{firehose:error-output-type}/"

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.etl_db.name
        table_name    = aws_glue_catalog_table.weather_data.name
        role_arn      = aws_iam_role.firehose_role.arn
      }
    }
  }
}
