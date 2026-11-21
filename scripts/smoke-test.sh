#!/usr/bin/env bash
set -Eeuo pipefail

if (($# < 1 || $# > 2)); then
  printf 'Usage: %s <application-url> [expected-commit-sha]\n' "$0" >&2
  exit 64
fi

application_url=${1%/}
expected_commit=${2:-}
retry_count=${SMOKE_TEST_RETRIES:-18}
retry_interval=${SMOKE_TEST_INTERVAL_SECONDS:-10}

for command_name in curl jq; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf '%s is required.\n' "${command_name}" >&2
    exit 1
  }
done

for ((attempt = 1; attempt <= retry_count; attempt += 1)); do
  web_status=$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --connect-timeout 5 --max-time 10 "${application_url}/health" || true)
  api_payload=$(curl --fail --silent --show-error \
    --connect-timeout 5 --max-time 10 "${application_url}/api/platform" || true)

  if [[ ${web_status} == "200" ]] && jq -e '.service == "ecs-release-api"' <<<"${api_payload}" >/dev/null 2>&1; then
    deployed_commit=$(jq -r '.commitSha' <<<"${api_payload}")

    if [[ -z ${expected_commit} || ${deployed_commit} == "${expected_commit}" ]]; then
      printf 'Smoke test passed on attempt %s.\n' "${attempt}"
      jq . <<<"${api_payload}"
      exit 0
    fi

    printf 'Attempt %s: expected commit %s, received %s.\n' \
      "${attempt}" "${expected_commit}" "${deployed_commit}" >&2
  else
    printf 'Attempt %s: web status=%s; API not ready.\n' "${attempt}" "${web_status}" >&2
  fi

  if ((attempt < retry_count)); then
    sleep "${retry_interval}"
  fi
done

printf 'Smoke test failed after %s attempts.\n' "${retry_count}" >&2
exit 1
