#!/usr/bin/env bash
set -Eeuo pipefail

(($# == 8)) || {
  printf 'Usage: %s <region> <cluster> <service> <container> <image-uri> <environment> <version> <commit-sha>\n' "$0" >&2
  exit 64
}

aws_region=$1 cluster_name=$2 service_name=$3 container_name=$4
image_uri=$5 app_environment=$6 app_version=$7 commit_sha=$8

for cmd in aws jq; do
  command -v "${cmd}" >/dev/null 2>&1 || { printf '%s is required.\n' "${cmd}" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf -- "${tmp}"' EXIT

current_task_definition=$(
  aws ecs describe-services \
    --region "${aws_region}" --cluster "${cluster_name}" --services "${service_name}" \
    --query 'services[0].taskDefinition' --output text
)

[[ -n ${current_task_definition} && ${current_task_definition} != "None" ]] || {
  printf 'ECS service %s not found in cluster %s.\n' "${service_name}" "${cluster_name}" >&2
  exit 1
}

aws ecs describe-task-definition \
  --region "${aws_region}" --task-definition "${current_task_definition}" \
  --query taskDefinition --output json > "${tmp}/current.json"

jq \
  --arg container "${container_name}" \
  --arg image "${image_uri}" \
  --arg app_environment "${app_environment}" \
  --arg app_version "${app_version}" \
  --arg commit_sha "${commit_sha}" \
  '
    .containerDefinitions |= map(
      if .name == $container then
        .image = $image
        | if $container == "api" then
            .environment = (
              (.environment // [])
              | map(select(.name | IN("APP_ENVIRONMENT","APP_VERSION","COMMIT_SHA") | not))
              + [
                  {"name": "APP_ENVIRONMENT", "value": $app_environment},
                  {"name": "APP_VERSION",     "value": $app_version},
                  {"name": "COMMIT_SHA",      "value": $commit_sha}
                ]
            )
          else . end
      else . end
    )
    | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,
          .compatibilities,.registeredAt,.registeredBy,.deregisteredAt)
  ' "${tmp}/current.json" > "${tmp}/next.json"

jq -e --arg c "${container_name}" --arg i "${image_uri}" \
  '.containerDefinitions[] | select(.name == $c and .image == $i)' \
  "${tmp}/next.json" >/dev/null || {
  printf 'Container %s not found in task definition %s.\n' "${container_name}" "${current_task_definition}" >&2
  exit 1
}

next_task_definition=$(
  aws ecs register-task-definition \
    --region "${aws_region}" --cli-input-json "file://${tmp}/next.json" \
    --query 'taskDefinition.taskDefinitionArn' --output text
)

aws ecs update-service \
  --region "${aws_region}" --cluster "${cluster_name}" \
  --service "${service_name}" --task-definition "${next_task_definition}" >/dev/null

printf 'Updated %s → %s\n' "${current_task_definition}" "${next_task_definition}" >&2
printf '%s\n' "${next_task_definition}"
