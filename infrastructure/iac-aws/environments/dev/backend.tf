terraform {
  backend "s3" {
    bucket         = "saas-mfe-terraform-state-ait-2025"
    key            = "iac-aws/dev/terraform.tfstate" # This key isolates state per environment
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "saas-mfe-tf-lock"
  }
}



