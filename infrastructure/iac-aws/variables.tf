# This file is for reference only.
# Each environment (dev/prod) has its own variables.tf file with variable declarations.
# This file documents the common variable structure across environments.
#
# Variable declarations should be in:
# - environments/dev/variables.tf
# - environments/prod/variables.tf
#
# Variable values should be in:
# - environments/dev/dev.auto.tfvars
# - environments/prod/prod.auto.tfvars

# Common variables used across environments:
# - aws_region: The default AWS region for the provider and backend configuration
# - environment: Target environment (dev or prod). Used for S3 backend state key and resource tags
# - target_account_id: The ID of the target AWS account where resources will be deployed
# - deployment_role_name: The IAM role name to assume in the target account for deployment
# - project_name_prefix: Prefix for naming all resources
# - vpc_cidr_block: CIDR block for the main VPC