terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Use a named profile (e.g. from aws configure --profile myprofile):
  profile = "terraform"
}