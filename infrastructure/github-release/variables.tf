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

variable "github_repository" {
  description = "GitHub repository allowed to release, as <owner>/<repo>. Case-sensitive: it must match the OIDC sub claim exactly."
  type        = string
  default     = "LordSesay/production-ecs-platform"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like <owner>/<repo>."
  }
}

variable "github_environment" {
  description = "GitHub Actions environment whose jobs may assume the release role."
  type        = string
  default     = "prod"
}

variable "create_oidc_provider" {
  description = "Create the account's GitHub OIDC provider. Set false if it already exists in this account."
  type        = bool
  default     = true
}
