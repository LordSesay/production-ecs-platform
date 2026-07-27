#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: %s <region> <cluster> <service> <container> <image-uri> <environment> <version> <commit-sha>\n' "$0" >&2
}

if (($# != 8)); then
  usage
  exit 64
fi

aws_region=$1
cluster_name=$2
service_name=$3
container_name=$4
image_uri=$5
application_environment=$6
application_version=$7
commit_sha=$8

for command_name in aws jq; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf '%s is required.\n' "${command_name}" >&2
    exit 1
  }
done

temporary_directory=$(mktemp -d)
trap 'rm -rf -- "${temporary_directory}"' EXIT

current_task_definition=$(
  aws ecs describe-services \
    --region "${aws_region}" \
    --cluster "${cluster_name}" \
    --services "${service_name}" \
    --query 'services[0].taskDefinition' \
    --output text
)

if [[ -z ${current_task_definition} || ${current_task_definition} == "None" ]]; then
  printf 'ECS service %s was not found in cluster %s.\n' "${service_name}" "${cluster_name}" >&2
  exit 1
fi

aws ecs describe-task-definition \
  --region "${aws_region}" \
  --task-definition "${current_task_definition}" \
  --query taskDefinition \
  --output json >"${temporary_directory}/current.json"

jq \
  --arg container "${container_name}" \
  --arg image "${image_uri}" \
  --arg app_environment "${application_environment}" \
  --arg app_version "${application_version}" \
  --arg commit_sha "${commit_sha}" \
  '
    .containerDefinitions |= map(
      if .name == $container then
        .image = $image
        | if $container == "api" then
            .environment = (
              (.environment // [])
              | map(select(.name != "APP_ENVIRONMENT" and .name != "APP_VERSION" and .name != "COMMIT_SHA"))
              + [
                  {"name": "APP_ENVIRONMENT", "value": $app_environment},
                  {"name": "APP_VERSION", "value": $app_version},
                  {"name": "COMMIT_SHA", "value": $commit_sha}
                ]
            )
          else
            .
          end
      else
        .
      end
    )
    | del(
        .taskDefinitionArn,
        .revision,
        .status,
        .requiresAttributes,
        .compatibilities,
        .registeredAt,
        .registeredBy,
        .deregisteredAt
      )
  ' "${temporary_directory}/current.json" >"${temporary_directory}/next.json"

if ! jq -e --arg container "${container_name}" --arg image "${image_uri}" \
  '.containerDefinitions[] | select(.name == $container and .image == $image)' \
  "${temporary_directory}/next.json" >/dev/null; then
  printf 'Container %s was not found in task definition %s.\n' "${container_name}" "${current_task_definition}" >&2
  exit 1
fi

next_task_definition=$(
  aws ecs register-task-definition \
    --region "${aws_region}" \
    --cli-input-json "file://${temporary_directory}/next.json" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text
)

aws ecs update-service \
  --region "${aws_region}" \
  --cluster "${cluster_name}" \
  --service "${service_name}" \
  --task-definition "${next_task_definition}" >/dev/null

printf 'Updated %s from %s to %s\n' \
  "${service_name}" "${current_task_definition}" "${next_task_definition}" >&2
printf '%s\n' "${next_task_definition}"
