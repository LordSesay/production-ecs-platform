output "application_url" {
  value = data.terraform_remote_state.foundation.outputs.application_url
}

output "ecs_cluster_name" {
  value = data.terraform_remote_state.foundation.outputs.ecs_cluster_name
}

output "service_names" {
  value = {
    for name, service in aws_ecs_service.service : name => service.name
  }
}

output "task_definition_arns" {
  value = {
    for name, task_definition in aws_ecs_task_definition.service : name => task_definition.arn
  }
}

output "initial_image_digests" {
  value = {
    for name, image in data.aws_ecr_image.release : name => image.image_digest
  }
}
