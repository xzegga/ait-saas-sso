terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Instruction for the provider to assume the role in the target account (Client-Tlinks-Dev)
  assume_role {
    # ARN of the role in the target account
    role_arn = "arn:aws:iam::${var.target_account_id}:role/${var.deployment_role_name}" 
  }
}



