locals {
  name_prefix = data.terraform_remote_state.foundation.outputs.name_prefix

  services = {
    web = {
      image_uri         = var.web_image_uri
      container_port    = 8080
      desired_count     = var.web_desired_count
      target_group_arn  = data.terraform_remote_state.foundation.outputs.web_target_group_arn
      security_group_id = data.terraform_remote_state.foundation.outputs.web_task_security_group_id
      log_group_name    = data.terraform_remote_state.foundation.outputs.log_group_names.web
      cpu               = 256
      memory            = 512
      environment       = []
    }
    api = {
      image_uri         = var.api_image_uri
      container_port    = 3000
      desired_count     = var.api_desired_count
      target_group_arn  = data.terraform_remote_state.foundation.outputs.api_target_group_arn
      security_group_id = data.terraform_remote_state.foundation.outputs.api_task_security_group_id
      log_group_name    = data.terraform_remote_state.foundation.outputs.log_group_names.api
      cpu               = 256
      memory            = 512
      environment = [
        {
          name  = "APP_ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "APP_VERSION"
          value = var.application_version
        },
        {
          name  = "COMMIT_SHA"
          value = var.commit_sha
        },
        {
          name  = "SERVICE_NAME"
          value = "ecs-release-api"
        },
        {
          name  = "PORT"
          value = "3000"
        }
      ]
    }
  }

  alarm_actions = var.alarm_sns_topic_arn == null ? [] : [var.alarm_sns_topic_arn]
}
