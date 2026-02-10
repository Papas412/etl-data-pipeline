# versions.tf

terraform {
  backend "s3" {
    bucket       = "papas412-tf-state-2026" # Must match Step 1
    key          = "dev/terraform.tfstate"  # Path inside the bucket
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
    profile      = "terraform" # Your specific AWS profile
  }
}