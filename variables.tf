variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "iam-zero-trust"
}

variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "corporate_ip_range" {
  description = "Corporate IP range for conditional access policies."
  type        = string
  default     = "203.0.113.0/24"  # RFC 5737 test range - replace with actual corporate IP
}

variable "admin_users" {
  description = "List of admin user names."
  type        = list(string)
  default     = ["admin1", "admin2"]
}

variable "developer_users" {
  description = "List of developer user names."
  type        = list(string)
  default     = ["dev1", "dev2"]
}

variable "readonly_users" {
  description = "List of readonly user names."
  type        = list(string)
  default     = ["readonly1"]
}

variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}
