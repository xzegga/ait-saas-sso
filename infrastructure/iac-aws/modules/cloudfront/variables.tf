variable "project_name_prefix" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_id" {
  description = "The ID of the S3 bucket to serve via CloudFront"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket (for origin ID)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN of the S3 bucket (for bucket policy)"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket (e.g., bucket.s3.us-east-1.amazonaws.com)"
  type        = string
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "Price class for CloudFront distribution (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100" # Only North America and Europe (cheapest)
}

variable "geo_restriction_type" {
  description = "Type of geo restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction (only used if geo_restriction_type is whitelist or blacklist)"
  type        = list(string)
  default     = []
}


