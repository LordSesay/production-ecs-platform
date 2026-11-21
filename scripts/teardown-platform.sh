#!/usr/bin/env bash
# Destroys the billable platform in reverse dependency order:
#   jenkins -> workload -> ECR images -> foundation
# The Terraform state bucket is retained on purpose (prevent_destroy).
# Each terraform destroy stays interactive so the plan is reviewed first.
set -Eeuo pipefail

for var in AWS_REGION TF_STATE_BUCKET PROJECT_NAME ENVIRONMENT; do
  [[ -n ${!var:-} ]] || { printf '%s must be set.\n' "${var}" >&2; exit 64; }
done

name_prefix="${PROJECT_NAME}-${ENVIRONMENT}"

[[ ${CONFIRM_DESTROY:-} == "${name_prefix}" ]] || {
  printf 'Set CONFIRM_DESTROY=%s to destroy that environment.\n' "${name_prefix}" >&2
  exit 64
}

for cmd in aws jq terraform; do
  command -v "${cmd}" >/dev/null 2>&1 || { printf '%s is required.\n' "${cmd}" >&2; exit 1; }
done

tmp=$(mktemp -d)
trap 'rm -rf -- "${tmp}"' EXIT

base_key="production-ecs-platform/${ENVIRONMENT}"
common_vars=(
  -var="aws_region=${AWS_REGION}"
  -var="project_name=${PROJECT_NAME}"
  -var="environment=${ENVIRONMENT}"
)
downstream_vars=(
  -var="state_bucket_name=${TF_STATE_BUCKET}"
  -var="foundation_state_key=${base_key}/foundation.tfstate"
)

tf_init() {
  local module=$1 state_key=$2
  printf 'bucket       = "%s"\nkey          = "%s"\nregion       = "%s"\nencrypt      = true\nuse_lockfile = true\n' \
    "${TF_STATE_BUCKET}" "${state_key}" "${AWS_REGION}" > "${tmp}/${module}.hcl"
  terraform -chdir="infrastructure/${module}" init -reconfigure -input=false \
    -backend-config="${tmp}/${module}.hcl" >/dev/null
}

has_resources() {
  [[ -n $(terraform -chdir="infrastructure/$1" state list 2>/dev/null) ]]
}

# The workload stack looks up its image tags in ECR even while destroying, so it
# must be destroyed before the images are purged. The running images are used
# unless WEB_IMAGE_URI / API_IMAGE_URI are provided.
running_image() {
  local service=$1 task_definition
  task_definition=$(
    aws ecs describe-services \
      --region "${AWS_REGION}" --cluster "${name_prefix}" --services "${name_prefix}-${service}" \
      --query 'services[0].taskDefinition' --output text 2>/dev/null || true
  )
  [[ -n ${task_definition} && ${task_definition} != "None" ]] || {
    printf 'Could not find the running %s image; set %s_IMAGE_URI explicitly.\n' \
      "${service}" "${service^^}" >&2
    return 1
  }
  aws ecs describe-task-definition \
    --region "${AWS_REGION}" --task-definition "${task_definition}" \
    --query "taskDefinition.containerDefinitions[?name=='${service}'].image | [0]" \
    --output text
}

purge_repository() {
  local repository=$1 image_ids
  if ! aws ecr describe-repositories --region "${AWS_REGION}" \
    --repository-names "${repository}" >/dev/null 2>&1; then
    printf 'ECR repository %s not found; skipping.\n' "${repository}"
    return
  fi

  while true; do
    image_ids=$(
      aws ecr list-images \
        --region "${AWS_REGION}" --repository-name "${repository}" --max-items 100 \
        --query 'imageIds[].{imageDigest: imageDigest}' --output json |
        jq -c 'unique'
    )
    [[ $(jq 'length' <<<"${image_ids}") -gt 0 ]] || break
    aws ecr batch-delete-image \
      --region "${AWS_REGION}" --repository-name "${repository}" \
      --image-ids "${image_ids}" >/dev/null
  done
  printf 'Purged images from %s.\n' "${repository}"
}

printf '\n== 1/4 Jenkins controller ==\n'
tf_init jenkins "${base_key}/jenkins.tfstate"
if has_resources jenkins; then
  terraform -chdir=infrastructure/jenkins destroy "${common_vars[@]}" "${downstream_vars[@]}"
else
  printf 'No Jenkins resources in state; skipping.\n'
fi

printf '\n== 2/4 Workload services ==\n'
tf_init workload "${base_key}/workload.tfstate"
if has_resources workload; then
  web_image=${WEB_IMAGE_URI:-$(running_image web)}
  api_image=${API_IMAGE_URI:-$(running_image api)}
  commit_sha=${api_image##*:sha-}

  terraform -chdir=infrastructure/workload destroy \
    "${common_vars[@]}" "${downstream_vars[@]}" \
    -var="web_image_uri=${web_image}" \
    -var="api_image_uri=${api_image}" \
    -var="commit_sha=${commit_sha}"
else
  printf 'No workload resources in state; skipping.\n'
fi

printf '\n== 3/4 ECR images ==\n'
purge_repository "${name_prefix}-web"
purge_repository "${name_prefix}-api"

printf '\n== 4/4 Foundation ==\n'
tf_init foundation "${base_key}/foundation.tfstate"
if has_resources foundation; then
  terraform -chdir=infrastructure/foundation destroy "${common_vars[@]}"
else
  printf 'No foundation resources in state; skipping.\n'
fi

printf '\nTeardown complete. Retained on purpose: state bucket %s.\n' "${TF_STATE_BUCKET}"
printf 'The logs KMS key stays in a 7-day pending-deletion window.\n'
printf 'Resources still tagged Project=%s (review; recently deleted ARNs can linger briefly):\n' "${PROJECT_NAME}"
aws resourcegroupstaggingapi get-resources \
  --region "${AWS_REGION}" \
  --tag-filters "Key=Project,Values=${PROJECT_NAME}" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
