output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  value = var.aws_region
}

output "name_prefix" {
  value = local.name_prefix
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "private_subnet_ids" {
  value = [for az in local.azs : aws_subnet.private[az].id]
}

output "public_subnet_ids" {
  value = [for az in local.azs : aws_subnet.public[az].id]
}

output "alb_dns_name" {
  value = aws_lb.application.dns_name
}

output "application_url" {
  value = local.application_url
}

output "web_target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "web_target_group_arn_suffix" {
  value = aws_lb_target_group.web.arn_suffix
}

output "api_target_group_arn" {
  value = aws_lb_target_group.api.arn
}

output "api_target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

output "load_balancer_arn_suffix" {
  value = aws_lb.application.arn_suffix
}

output "web_task_security_group_id" {
  value = aws_security_group.web_tasks.id
}

output "api_task_security_group_id" {
  value = aws_security_group.api_tasks.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "ecr_repository_urls" {
  value = {
    for name, repository in aws_ecr_repository.service : name => repository.repository_url
  }
}

output "ecr_repository_arns" {
  value = {
    for name, repository in aws_ecr_repository.service : name => repository.arn
  }
}

output "log_group_names" {
  value = {
    for name, log_group in aws_cloudwatch_log_group.service : name => log_group.name
  }
}
