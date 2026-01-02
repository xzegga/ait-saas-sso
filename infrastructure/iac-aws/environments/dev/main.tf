# Root module for DEV environment
# Variable values are loaded from dev.auto.tfvars
# Variable declarations are in variables.tf

# 1. NETWORK MODULE
module "network" {
  source = "../../modules/network"

  # Inputs
  project_name_prefix = var.project_name_prefix
  environment         = var.environment
  vpc_cidr_block      = var.vpc_cidr_block
  common_tags         = local.common_tags
}

# 2. VALKEY MODULE (Serverless for DEV to optimize costs)
module "redis" {
  source = "../../modules/redis"

  # Inputs (Uses outputs from the network module)
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids # Uses the public subnets defined in the network module
  project_name_prefix = var.project_name_prefix
  environment         = var.environment
  common_tags         = local.common_tags
  
  # Use Serverless for DEV to pay only for usage
  use_serverless         = true
  serverless_max_storage  = 5  # 5 GB max storage
  serverless_max_ecpu     = 5000  # 5000 ECPU per second max
}

# 3. S3 BUCKET FOR STATIC HOSTING
resource "aws_s3_bucket" "mfe_static_hosting" {
  bucket = "${var.project_name_prefix}-${var.environment}-mfe-static-hosting"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name_prefix}-${var.environment}-mfe-static-hosting"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "mfe_bucket_block" {
  bucket = aws_s3_bucket.mfe_static_hosting.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}