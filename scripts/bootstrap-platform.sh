#!/usr/bin/env bash
set -Eeuo pipefail

for var in AWS_REGION TF_STATE_BUCKET PROJECT_NAME ENVIRONMENT APP_VERSION CONFIRM_AWS_CHARGES; do
  [[ -n ${!var:-} ]] || { printf '%s must be set.\n' "${var}" >&2; exit 64; }
done

[[ ${CONFIRM_AWS_CHARGES} == "yes" ]] || {
  printf 'Set CONFIRM_AWS_CHARGES=yes after reviewing the Terraform plans and expected AWS cost.\n' >&2
  exit 64
}

for cmd in aws docker git jq terraform; do
  command -v "${cmd}" >/dev/null 2>&1 || { printf '%s is required.\n' "${cmd}" >&2; exit 1; }
done

commit_sha=${COMMIT_SHA:-$(git rev-parse HEAD)}
tmp=$(mktemp -d)
trap 'rm -rf -- "${tmp}"' EXIT

tf_deploy() {
  local module=$1 state_key=$2
  shift 2
  printf 'bucket       = "%s"\nkey          = "%s"\nregion       = "%s"\nencrypt      = true\nuse_lockfile = true\n' \
    "${TF_STATE_BUCKET}" "${state_key}" "${AWS_REGION}" > "${tmp}/${module}.hcl"
  terraform -chdir="infrastructure/${module}" init -reconfigure -backend-config="${tmp}/${module}.hcl"
  terraform -chdir="infrastructure/${module}" apply \
    -var="aws_region=${AWS_REGION}" \
    -var="project_name=${PROJECT_NAME}" \
    -var="environment=${ENVIRONMENT}" \
    "$@"
}

base_key="production-ecs-platform/${ENVIRONMENT}"

printf 'Bootstrapping the protected Terraform state bucket...\n'
terraform -chdir=infrastructure/bootstrap-state init
terraform -chdir=infrastructure/bootstrap-state apply \
  -var="aws_region=${AWS_REGION}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="state_bucket_name=${TF_STATE_BUCKET}"

tf_deploy foundation "${base_key}/foundation.tfstate"

web_repository=$(terraform -chdir=infrastructure/foundation output -json ecr_repository_urls | jq -r .web)
api_repository=$(terraform -chdir=infrastructure/foundation output -json ecr_repository_urls | jq -r .api)

scripts/build-and-push.sh "${AWS_REGION}" "${web_repository}" "${api_repository}" "${commit_sha}"

tf_deploy workload "${base_key}/workload.tfstate" \
  -var="state_bucket_name=${TF_STATE_BUCKET}" \
  -var="foundation_state_key=${base_key}/foundation.tfstate" \
  -var="web_image_uri=${web_repository}:sha-${commit_sha}" \
  -var="api_image_uri=${api_repository}:sha-${commit_sha}" \
  -var="application_version=${APP_VERSION}" \
  -var="commit_sha=${commit_sha}"

application_url=$(terraform -chdir=infrastructure/workload output -raw application_url)
scripts/smoke-test.sh "${application_url}" "${commit_sha}"

tf_deploy jenkins "${base_key}/jenkins.tfstate" \
  -var="state_bucket_name=${TF_STATE_BUCKET}" \
  -var="foundation_state_key=${base_key}/foundation.tfstate"

printf '\nBootstrap complete.\n'
printf 'Application URL: %s\n' "${application_url}"
printf 'Jenkins access command:\n%s\n' \
  "$(terraform -chdir=infrastructure/jenkins output -raw ssm_tunnel_command)"
