resource "aws_s3_bucket" "data_bucket-raw-papas412" {
  bucket = var.raw_bucket_name

  tags = var.project_tags
}

resource "aws_s3_bucket" "data_bucket-processed-papas412" {
  bucket = var.processed_bucket_name

  tags = var.project_tags
}

resource "aws_s3_bucket" "data_bucket-final-papas412" {
  bucket = var.final_bucket_name

  tags = var.project_tags
}

resource "aws_iam_role" "etl_lambda_role" {
  name = "etl-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.etl_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.etl_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role" "glue_service_role" {
  name = "glue-service-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "glue.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue-svc" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue-svc-s3" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_iam_policy" "lambda_firehose_policy" {
  name        = "lambda_firehose_policy"
  description = "Allow Lambda to put records into Firehose"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_firehose_delivery_stream.weather_stream.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_firehose_attach" {
  role       = aws_iam_role.etl_lambda_role.name
  policy_arn = aws_iam_policy.lambda_firehose_policy.arn
}

resource "aws_lambda_function" "csv-preprocessor-lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "etl-lambda"
  role          = aws_iam_role.etl_lambda_role.arn

  # "lambda.handler" means: look in lambda.py for a function named def handler()
  handler = "lambda.lambda_handler"
  runtime = "python3.9"

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.data_bucket-processed-papas412.bucket
      FIREHOSE_STREAM  = aws_kinesis_firehose_delivery_stream.weather_stream.name
    }
  }

  # This ensures the Lambda is updated when the code changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 1. Allow S3 to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv-preprocessor-lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket-raw-papas412.arn
}

# 2. Configure the S3 notification trigger
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.data_bucket-raw-papas412.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv-preprocessor-lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  # This ensures the permission is created BEFORE the notification
  depends_on = [aws_lambda_permission.allow_s3_trigger]
}