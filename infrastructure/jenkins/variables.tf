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

variable "instance_type" {
  description = "EC2 size for the single-node Jenkins controller."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 root volume size."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size_gib >= 20
    error_message = "root_volume_size_gib must be at least 20 GiB."
  }
}

variable "jenkins_version" {
  description = "Jenkins RPM package version. Set null to install the current LTS package."
  type        = string
  default     = null
}
