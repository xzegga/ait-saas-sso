locals {
  common_tags = {
    Project     = "saas-mfe"
    Environment = var.environment
    ManagedBy   = "Terraform"
    ProjectName = var.project_name_prefix
  }
}



