variable "project_name_prefix" {
  type = string
}
variable "environment" {
  type = string
}
variable "vpc_cidr_block" {
  type = string
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}