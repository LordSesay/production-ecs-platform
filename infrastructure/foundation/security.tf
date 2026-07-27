resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Public ingress to the application load balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.certificate_arn == null ? 0 : 1

  security_group_id = aws_security_group.alb.id
  description       = "Public HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_security_group" "web_tasks" {
  name        = "${local.name_prefix}-web-tasks"
  description = "Network boundary for web ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-web-tasks"
  }
}

resource "aws_security_group" "api_tasks" {
  name        = "${local.name_prefix}-api-tasks"
  description = "Network boundary for API ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-api-tasks"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web_tasks.id
  description                  = "Web traffic from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api_tasks.id
  description                  = "API traffic from the ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3000
  ip_protocol                  = "tcp"
  to_port                      = 3000
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to web tasks"
  referenced_security_group_id = aws_security_group.web_tasks.id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to API tasks"
  referenced_security_group_id = aws_security_group.api_tasks.id
  from_port                    = 3000
  ip_protocol                  = "tcp"
  to_port                      = 3000
}

resource "aws_vpc_security_group_egress_rule" "task_https" {
  for_each = {
    web = aws_security_group.web_tasks.id
    api = aws_security_group.api_tasks.id
  }

  security_group_id = each.value
  description       = "HTTPS egress for ECR, logs, and AWS control-plane endpoints"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "task_dns_udp" {
  for_each = {
    web = aws_security_group.web_tasks.id
    api = aws_security_group.api_tasks.id
  }

  security_group_id = each.value
  description       = "DNS resolution within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  ip_protocol       = "udp"
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "task_dns_tcp" {
  for_each = {
    web = aws_security_group.web_tasks.id
    api = aws_security_group.api_tasks.id
  }

  security_group_id = each.value
  description       = "DNS resolution fallback within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  ip_protocol       = "tcp"
  to_port           = 53
}
