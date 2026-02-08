resource "aws_s3_bucket" "data_bucket-raw-papas412" {
    bucket = "papas412-etl-raw-bucket"

    tags = {
        Name = "etl-raw-bucket"
    }
}

resource "aws_s3_bucket" "data_bucket-processed-papas412" {
    bucket = "papas412-etl-processed-bucket"

    tags = {
        Name = "etl-processed-bucket"
    }
}

resource "aws_s3_bucket" "data_bucket-final-papas412" {
    bucket = "papas412-etl-final-bucket"

    tags = {
        Name = "etl-final-bucket"
    }
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
    role = aws_iam_role.etl_lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service" {
    role = aws_iam_role.etl_lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role" "glue_service_role" {
    name = "etl-glue-role"

    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "glue.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "glue-svc" {
    role = aws_iam_role.glue_service_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue-svc-s3" {
    role = aws_iam_role.glue_service_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}