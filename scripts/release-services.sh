#!/usr/bin/env bash
# Releases one commit to both ECS services:
#   record current revisions -> deploy API -> deploy web -> wait for stable
#   -> verify the deployed commit through the ALB
# If any step fails, both services are restored to the recorded revisions.
#
# CI-agnostic: the GitHub Actions release workflow calls it, and it runs by
# hand with the same environment variables. Images must already be in ECR.
#
# No -E on purpose: with errtrace, a failure inside next_api=$(...) would fire
# the ERR trap in the command substitution and again in this shell, rolling
# back twice. Without it, the failed assignment fires the trap once, here.
set -euo pipefail

required=(
  AWS_REGION ECS_CLUSTER API_ECS_SERVICE WEB_ECS_SERVICE
  API_IMAGE_URI WEB_IMAGE_URI APP_ENVIRONMENT APP_VERSION COMMIT_SHA APPLICATION_URL
)
for var in "${required[@]}"; do
  [[ -n ${!var:-} ]] || { printf '%s must be set.\n' "${var}" >&2; exit 64; }
done

for cmd in aws curl jq; do
  command -v "${cmd}" >/dev/null 2>&1 || { printf '%s is required.\n' "${cmd}" >&2; exit 1; }
done

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

current_task_definition() {
  aws ecs describe-services \
    --region "${AWS_REGION}" --cluster "${ECS_CLUSTER}" --services "$1" \
    --query 'services[0].taskDefinition' --output text
}

previous_api=$(current_task_definition "${API_ECS_SERVICE}")
previous_web=$(current_task_definition "${WEB_ECS_SERVICE}")

rollback_release() {
  printf 'Release failed; restoring both previous task definitions.\n' >&2
  "${scripts_dir}/rollback-service.sh" \
    "${AWS_REGION}" "${ECS_CLUSTER}" "${API_ECS_SERVICE}" "${previous_api}" || true
  "${scripts_dir}/rollback-service.sh" \
    "${AWS_REGION}" "${ECS_CLUSTER}" "${WEB_ECS_SERVICE}" "${previous_web}" || true
}
trap rollback_release ERR

next_api=$(
  "${scripts_dir}/deploy-service.sh" \
    "${AWS_REGION}" "${ECS_CLUSTER}" "${API_ECS_SERVICE}" api \
    "${API_IMAGE_URI}" "${APP_ENVIRONMENT}" "${APP_VERSION}" "${COMMIT_SHA}"
)
next_web=$(
  "${scripts_dir}/deploy-service.sh" \
    "${AWS_REGION}" "${ECS_CLUSTER}" "${WEB_ECS_SERVICE}" web \
    "${WEB_IMAGE_URI}" "${APP_ENVIRONMENT}" "${APP_VERSION}" "${COMMIT_SHA}"
)

aws ecs wait services-stable \
  --region "${AWS_REGION}" --cluster "${ECS_CLUSTER}" \
  --services "${API_ECS_SERVICE}" "${WEB_ECS_SERVICE}"

"${scripts_dir}/smoke-test.sh" "${APPLICATION_URL}" "${COMMIT_SHA}"
trap - ERR

# Release record. Account IDs are redacted because CI logs and summaries of a
# public repository are public.
redact() { sed -E 's/[0-9]{12}/<account>/g'; }
record=$(
  cat <<EOF
| Item | Value |
|---|---|
| Commit | \`${COMMIT_SHA}\` |
| API image | \`${API_IMAGE_URI}\` |
| Web image | \`${WEB_IMAGE_URI}\` |
| API task definition | \`${previous_api##*/}\` → \`${next_api##*/}\` |
| Web task definition | \`${previous_web##*/}\` → \`${next_web##*/}\` |
| Smoke test | \`/api/platform\` reported this commit |
EOF
)
redacted_record=$(redact <<<"${record}")
printf '%s\n' "${redacted_record}"
if [[ -n ${RELEASE_SUMMARY_FILE:-} ]]; then
  printf '### Release verified\n\n%s\n' "${redacted_record}" >> "${RELEASE_SUMMARY_FILE}"
fi
