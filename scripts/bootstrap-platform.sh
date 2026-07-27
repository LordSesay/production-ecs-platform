#!/usr/bin/env bash
set -Eeuo pipefail

required_variables=(
  AWS_REGION
  TF_STATE_BUCKET
  PROJECT_NAME
  ENVIRONMENT
  APP_VERSION
  CONFIRM_AWS_CHARGES
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z ${!variable_name:-} ]]; then
    printf '%s must be set.\n' "${variable_name}" >&2
    exit 64
  fi
done

if [[ ${CONFIRM_AWS_CHARGES} != "yes" ]]; then
  printf 'Set CONFIRM_AWS_CHARGES=yes after reviewing the Terraform plans and expected AWS cost.\n' >&2
  exit 64
fi

for command_name in aws docker git jq terraform; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf '%s is required.\n' "${command_name}" >&2
    exit 1
  }
done

commit_sha=${COMMIT_SHA:-$(git rev-parse HEAD)}
foundation_key="production-ecs-platform/${ENVIRONMENT}/foundation.tfstate"
workload_key="production-ecs-platform/${ENVIRONMENT}/workload.tfstate"
jenkins_key="production-ecs-platform/${ENVIRONMENT}/jenkins.tfstate"
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "${temporary_directory}"' EXIT

write_backend_config() {
  local state_key=$1
  local destination=$2

  {
    printf 'bucket       = "%s"\n' "${TF_STATE_BUCKET}"
    printf 'key          = "%s"\n' "${state_key}"
    printf 'region       = "%s"\n' "${AWS_REGION}"
    printf 'encrypt      = true\n'
    printf 'use_lockfile = true\n'
  } >"${destination}"
}

printf 'Bootstrapping the protected Terraform state bucket...\n'
terraform -chdir=infrastructure/bootstrap-state init
terraform -chdir=infrastructure/bootstrap-state apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="state_bucket_name=${TF_STATE_BUCKET}"

write_backend_config "${foundation_key}" "${temporary_directory}/foundation.hcl"
terraform -chdir=infrastructure/foundation init \
  -reconfigure \
  -backend-config="${temporary_directory}/foundation.hcl"
terraform -chdir=infrastructure/foundation apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="environment=${ENVIRONMENT}"

web_repository=$(terraform -chdir=infrastructure/foundation output -json ecr_repository_urls | jq -r .web)
api_repository=$(terraform -chdir=infrastructure/foundation output -json ecr_repository_urls | jq -r .api)

scripts/build-and-push.sh \
  "${AWS_REGION}" \
  "${web_repository}" \
  "${api_repository}" \
  "${commit_sha}"

write_backend_config "${workload_key}" "${temporary_directory}/workload.hcl"
terraform -chdir=infrastructure/workload init \
  -reconfigure \
  -backend-config="${temporary_directory}/workload.hcl"
terraform -chdir=infrastructure/workload apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="environment=${ENVIRONMENT}" \
  -var="state_bucket_name=${TF_STATE_BUCKET}" \
  -var="foundation_state_key=${foundation_key}" \
  -var="web_image_uri=${web_repository}:sha-${commit_sha}" \
  -var="api_image_uri=${api_repository}:sha-${commit_sha}" \
  -var="application_version=${APP_VERSION}" \
  -var="commit_sha=${commit_sha}"

application_url=$(terraform -chdir=infrastructure/workload output -raw application_url)
scripts/smoke-test.sh "${application_url}" "${commit_sha}"

write_backend_config "${jenkins_key}" "${temporary_directory}/jenkins.hcl"
terraform -chdir=infrastructure/jenkins init \
  -reconfigure \
  -backend-config="${temporary_directory}/jenkins.hcl"
terraform -chdir=infrastructure/jenkins apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="environment=${ENVIRONMENT}" \
  -var="state_bucket_name=${TF_STATE_BUCKET}" \
  -var="foundation_state_key=${foundation_key}"

printf '\nBootstrap complete.\n'
printf 'Application URL: %s\n' "${application_url}"
printf 'Jenkins access command:\n%s\n' \
  "$(terraform -chdir=infrastructure/jenkins output -raw ssm_tunnel_command)"
