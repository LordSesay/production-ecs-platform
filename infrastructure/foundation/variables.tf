variable "aws_region" {
  description = "AWS Region for the application platform."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project identifier used in names and tags."
  type        = string
  default     = "ecs-release-console"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project_name))
    error_message = "project_name must contain 3-24 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be dev, stage, or prod."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of Availability Zones. This project requires at least two."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for the cost-conscious lab profile. Set false for one per AZ."
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "Optional ACM certificate ARN. When set, HTTP redirects to HTTPS."
  type        = string
  default     = null

  validation {
    condition     = var.certificate_arn == null || can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "certificate_arn must be null or a valid ACM certificate ARN."
  }
}

variable "application_domain" {
  description = "Optional DNS name covered by certificate_arn. The Route 53 alias is managed outside this stack."
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Protect the ALB from accidental deletion."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period."
  type        = number
  default     = 30
}
