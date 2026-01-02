# This file is for reference only.
# Each environment (dev/prod) has its own providers.tf file with provider configuration.
#
# Provider configurations should be in:
# - environments/dev/providers.tf
# - environments/prod/providers.tf
#
# Each environment's providers.tf includes:
# - Terraform required_providers block
# - AWS provider configuration with assume_role for cross-account deployment