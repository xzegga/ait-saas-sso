terraform {
  backend "s3" {
    bucket         = "saas-mfe-terraform-state-ait-2025"
    key            = "iac-aws/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "saas-mfe-tf-lock"
  }
}



