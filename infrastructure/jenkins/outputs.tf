output "instance_id" {
  description = "Jenkins controller instance ID used for SSM sessions."
  value       = aws_instance.jenkins.id
}

output "private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "instance_role_arn" {
  value = aws_iam_role.jenkins.arn
}

output "ssm_tunnel_command" {
  description = "Run locally, then browse to http://localhost:8080."
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8080\"],\"localPortNumber\":[\"8080\"]}' --region ${var.aws_region}"
}

output "initial_admin_password_command" {
  description = "Run after connecting through SSM to retrieve the one-time Jenkins setup password."
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --region ${var.aws_region} --document-name AWS-StartInteractiveCommand --parameters command=\"sudo cat /var/lib/jenkins/secrets/initialAdminPassword\""
}
