variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "project_name_prefix" {
  type = string
}
variable "environment" {
  type = string
}
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
variable "use_serverless" {
  description = "Use ElastiCache Serverless instead of traditional cluster (recommended for dev)"
  type        = bool
  default     = false
}
variable "serverless_max_storage" {
  description = "Maximum storage in GB for Serverless cache (only used when use_serverless = true)"
  type        = number
  default     = 5
}
variable "serverless_max_ecpu" {
  description = "Maximum ECPU per second for Serverless cache (only used when use_serverless = true)"
  type        = number
  default     = 5000
}
variable "serverless_kms_key_id" {
  description = "KMS key ID for Serverless cache encryption (optional, only used when use_serverless = true)"
  type        = string
  default     = null
}