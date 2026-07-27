output "state_bucket_name" {
  description = "S3 bucket used by the remote Terraform backends."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS Region containing the state bucket."
  value       = var.aws_region
}
