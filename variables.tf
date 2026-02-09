variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "raw_bucket_name" {
  description = "Name of the S3 bucket for raw data"
  type        = string
  default     = "papas412-etl-raw-bucket"
}

variable "processed_bucket_name" {
  description = "Name of the S3 bucket for processed data"
  type        = string
  default     = "papas412-etl-processed-bucket"
}

variable "final_bucket_name" {
  description = "Name of the S3 bucket for final parquet data"
  type        = string
  default     = "papas412-etl-final-bucket"
}

variable "glue_db_name" {
  description = "Name of the Glue Catalog Database"
  type        = string
  default     = "weather_etl_db"
}

variable "project_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Project = "ETL-Pipeline"
    Owner   = "papas412"
  }
}
