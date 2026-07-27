resource "aws_ecs_task_definition" "service" {
  for_each = local.services

  family                   = "${local.name_prefix}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = data.terraform_remote_state.foundation.outputs.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.foundation.outputs.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "${each.key}-tmp"
  }

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image_uri
      essential = true

      portMappings = [
        {
          name          = "${each.key}-http"
          containerPort = each.value.container_port
          hostPort      = each.value.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = each.value.environment

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = each.value.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.key
        }
      }

      readonlyRootFilesystem = true
      user                   = each.key == "web" ? "101" : "10001"

      mountPoints = [
        {
          sourceVolume  = "${each.key}-tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]

      healthCheck = {
        command = each.key == "web" ? [
          "CMD-SHELL",
          "wget --quiet --tries=1 --spider http://127.0.0.1:8080/health || exit 1"
          ] : [
          "CMD-SHELL",
          "node -e \"fetch('http://127.0.0.1:3000/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_service" "service" {
  for_each = local.services

  name                               = "${local.name_prefix}-${each.key}"
  cluster                            = data.terraform_remote_state.foundation.outputs.ecs_cluster_arn
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  desired_count                      = each.value.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  enable_execute_command             = true
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    assign_public_ip = false
    subnets          = data.terraform_remote_state.foundation.outputs.private_subnet_ids
    security_groups  = [each.value.security_group_id]
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  lifecycle {
    # Jenkins owns release revisions after the Terraform bootstrap release.
    ignore_changes = [task_definition]
  }
}

resource "aws_appautoscaling_target" "service" {
  for_each = local.services

  max_capacity       = var.maximum_task_count
  min_capacity       = var.minimum_task_count
  resource_id        = "service/${data.terraform_remote_state.foundation.outputs.ecs_cluster_name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.services

  name               = "${local.name_prefix}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 120
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
