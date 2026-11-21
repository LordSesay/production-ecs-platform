locals {
  name_prefix       = data.terraform_remote_state.foundation.outputs.name_prefix
  oidc_provider_url = "https://token.actions.githubusercontent.com"
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# An AWS account holds one IAM OIDC provider per issuer URL. Set
# create_oidc_provider = false when another stack already created it.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = local.oidc_provider_url
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "release" {
  name                 = "${local.name_prefix}-github-release"
  description          = "Assumed only by GitHub Actions jobs in the ${var.github_environment} environment of ${var.github_repository}."
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "release" {
  name = "ecs-release"
  role = aws_iam_role.release.id

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
        Sid      = "DiscoverApplicationUrl"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:DescribeLoadBalancers"]
        Resource = "*"
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
