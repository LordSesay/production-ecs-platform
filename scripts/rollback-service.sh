#!/usr/bin/env bash
set -Eeuo pipefail

if (($# != 4)); then
  printf 'Usage: %s <region> <cluster> <service> <previous-task-definition-arn>\n' "$0" >&2
  exit 64
fi

aws_region=$1
cluster_name=$2
service_name=$3
previous_task_definition=$4

aws ecs update-service \
  --region "${aws_region}" \
  --cluster "${cluster_name}" \
  --service "${service_name}" \
  --task-definition "${previous_task_definition}" \
  --force-new-deployment >/dev/null

aws ecs wait services-stable \
  --region "${aws_region}" \
  --cluster "${cluster_name}" \
  --services "${service_name}"

printf 'Rolled back %s to %s\n' "${service_name}" "${previous_task_definition}"
