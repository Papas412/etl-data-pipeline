# backend_infra.tf

# 1. The S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket = "papas412-tf-state-2026"

  lifecycle {
    prevent_destroy = true # Protects your state from accidental deletion
  }
}

# 2. Enable Versioning (Essential for state recovery)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Enable Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}