resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  for_each = {
    web = data.terraform_remote_state.foundation.outputs.web_target_group_arn_suffix
    api = data.terraform_remote_state.foundation.outputs.api_target_group_arn_suffix
  }

  alarm_name          = "${local.name_prefix}-${each.key}-unhealthy-targets"
  alarm_description   = "One or more ${each.key} targets are unhealthy behind the ALB."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    LoadBalancer = data.terraform_remote_state.foundation.outputs.load_balancer_arn_suffix
    TargetGroup  = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "service_cpu" {
  for_each = local.services

  alarm_name          = "${local.name_prefix}-${each.key}-high-cpu"
  alarm_description   = "Sustained ECS service CPU utilization above 85 percent."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    ClusterName = data.terraform_remote_state.foundation.outputs.ecs_cluster_name
    ServiceName = aws_ecs_service.service[each.key].name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  alarm_description   = "Application Load Balancer is returning elevated 5xx responses."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    LoadBalancer = data.terraform_remote_state.foundation.outputs.load_balancer_arn_suffix
  }
}
