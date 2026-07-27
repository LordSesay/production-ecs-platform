locals {
  name_prefix = data.terraform_remote_state.foundation.outputs.name_prefix
}

resource "aws_security_group" "jenkins" {
  name        = "${local.name_prefix}-jenkins"
  description = "Private Jenkins controller; no inbound network access"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id

  tags = {
    Name = "${local.name_prefix}-jenkins"
  }
}

resource "aws_vpc_security_group_egress_rule" "jenkins_https" {
  security_group_id = aws_security_group.jenkins.id
  description       = "HTTPS egress for GitHub, package repositories, ECR, ECS, and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "jenkins_http" {
  security_group_id = aws_security_group.jenkins.id
  description       = "HTTP egress for package installation and redirect support"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "jenkins_dns_udp" {
  security_group_id = aws_security_group.jenkins.id
  description       = "DNS resolution within the VPC"
  cidr_ipv4         = data.terraform_remote_state.foundation.outputs.vpc_cidr
  from_port         = 53
  ip_protocol       = "udp"
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "jenkins_dns_tcp" {
  security_group_id = aws_security_group.jenkins.id
  description       = "DNS resolution fallback within the VPC"
  cidr_ipv4         = data.terraform_remote_state.foundation.outputs.vpc_cidr
  from_port         = 53
  ip_protocol       = "tcp"
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "jenkins_ntp" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Amazon Time Sync Service"
  cidr_ipv4         = "169.254.169.123/32"
  from_port         = 123
  ip_protocol       = "udp"
  to_port           = 123
}

resource "aws_iam_role" "jenkins" {
  name               = "${local.name_prefix}-jenkins"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "release" {
  name = "ecs-release"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushReleaseImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = values(data.terraform_remote_state.foundation.outputs.ecr_repository_arns)
      },
      {
        Sid    = "ReadAndRegisterTaskDefinitions"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeployKnownServices"
        Effect = "Allow"
        Action = ["ecs:DescribeServices", "ecs:UpdateService"]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.terraform_remote_state.foundation.outputs.aws_account_id}:service/${data.terraform_remote_state.foundation.outputs.ecs_cluster_name}/${local.name_prefix}-web",
          "arn:aws:ecs:${var.aws_region}:${data.terraform_remote_state.foundation.outputs.aws_account_id}:service/${data.terraform_remote_state.foundation.outputs.ecs_cluster_name}/${local.name_prefix}-api"
        ]
      },
      {
        Sid    = "PassTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          data.terraform_remote_state.foundation.outputs.task_execution_role_arn,
          data.terraform_remote_state.foundation.outputs.task_role_arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name_prefix}-jenkins"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.foundation.outputs.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false
  monitoring                  = true
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = var.root_volume_size_gib
  }

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    jenkins_package = var.jenkins_version == null ? "jenkins" : "jenkins-${var.jenkins_version}"
  })

  tags = {
    Name = "${local.name_prefix}-jenkins"
  }
}
