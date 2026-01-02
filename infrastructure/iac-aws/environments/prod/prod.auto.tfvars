# --- GLOBAL VARIABLES (providers.tf and backend.tf) ---
environment         = "prod"
# ID of the Client-Tlinks-Prod account
target_account_id   = "831873947634" 
deployment_role_name = "TerraformDeploymentRole"
aws_region          = "us-east-1"

# --- RESOURCE-SPECIFIC VARIABLES (Modules) ---
project_name_prefix = "saas-mfe-tlinks"
vpc_cidr_block      = "10.0.0.0/16"