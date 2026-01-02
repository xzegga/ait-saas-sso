# This file is for reference only.
# Each environment (dev/prod) has its own backend.tf file with backend configuration.
#
# Backend configurations should be in:
# - environments/dev/backend.tf
# - environments/prod/backend.tf
#
# Each environment's backend.tf uses a hardcoded key path to isolate state:
# - dev: "iac-aws/dev/terraform.tfstate"
# - prod: "iac-aws/prod/terraform.tfstate"
#
# Note: Variables cannot be used in backend configuration blocks.