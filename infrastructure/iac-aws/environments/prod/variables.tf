variable "aws_region" {
  description = "The default AWS region for the provider and backend configuration."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Target environment (dev or prod). Used for S3 backend state key and resource tags."
  type        = string
}

variable "target_account_id" {
  description = "The ID of the target AWS account where resources will be deployed (Client-Tlinks-Prod)."
  type        = string
}

variable "deployment_role_name" {
  description = "The IAM role name to assume in the target account for deployment."
  type        = string
  default     = "TerraformDeploymentRole"
}

variable "project_name_prefix" {
  description = "Prefix for naming all resources (e.g., saas-mfe-tlinks-prod)."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the main VPC."
  type        = string
}



