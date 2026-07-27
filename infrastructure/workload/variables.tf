variable "aws_region" {
  description = "AWS Region containing the platform."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier. Must match the foundation stack."
  type        = string
  default     = "ecs-release-console"
}

variable "environment" {
  description = "Deployment environment. Must match the foundation stack."
  type        = string
  default     = "prod"
}

variable "state_bucket_name" {
  description = "S3 bucket containing the foundation remote state."
  type        = string
}

variable "foundation_state_key" {
  description = "S3 object key for the foundation Terraform state."
  type        = string
  default     = "production-ecs-platform/prod/foundation.tfstate"
}

variable "web_image_uri" {
  description = "Immutable ECR URI for the initial web image."
  type        = string

  validation {
    condition     = can(regex(":(sha-[0-9a-f]{7,40})$", var.web_image_uri))
    error_message = "web_image_uri must end in an immutable sha-<git-commit> tag."
  }
}

variable "api_image_uri" {
  description = "Immutable ECR URI for the initial API image."
  type        = string

  validation {
    condition     = can(regex(":(sha-[0-9a-f]{7,40})$", var.api_image_uri))
    error_message = "api_image_uri must end in an immutable sha-<git-commit> tag."
  }
}

variable "application_version" {
  description = "Human-readable version reported by the initial API release."
  type        = string
  default     = "0.1.0"
}

variable "commit_sha" {
  description = "Git commit represented by the initial image URIs."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{7,40}$", var.commit_sha))
    error_message = "commit_sha must be a 7-40 character lowercase Git SHA."
  }
}

variable "web_desired_count" {
  description = "Steady-state number of web tasks."
  type        = number
  default     = 2
}

variable "api_desired_count" {
  description = "Steady-state number of API tasks."
  type        = number
  default     = 2
}

variable "minimum_task_count" {
  description = "Minimum autoscaling capacity for each service."
  type        = number
  default     = 2
}

variable "maximum_task_count" {
  description = "Maximum autoscaling capacity for each service."
  type        = number
  default     = 4

  validation {
    condition     = var.maximum_task_count >= var.minimum_task_count
    error_message = "maximum_task_count must be greater than or equal to minimum_task_count."
  }
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN for operational alarms."
  type        = string
  default     = null
}
