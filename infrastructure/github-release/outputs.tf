output "release_role_arn" {
  description = "Set as the AWS_RELEASE_ROLE_ARN variable on the GitHub environment."
  value       = aws_iam_role.release.arn
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

output "github_environment" {
  description = "GitHub environment that must exist, with a required reviewer and a main-only deployment branch rule."
  value       = var.github_environment
}
