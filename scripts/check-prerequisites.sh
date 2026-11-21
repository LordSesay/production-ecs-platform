#!/usr/bin/env bash
set -Eeuo pipefail

required_commands=(aws docker git jq npm terraform)
missing=()

for command_name in "${required_commands[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    missing+=("${command_name}")
  fi
done

if ((${#missing[@]} > 0)); then
  printf 'Missing required commands: %s\n' "${missing[*]}" >&2
  exit 1
fi

aws sts get-caller-identity >/dev/null
docker info >/dev/null

printf 'Prerequisites passed.\n'
printf 'AWS identity: %s\n' "$(aws sts get-caller-identity --query Arn --output text)"
printf 'Terraform: %s\n' "$(terraform version -json | jq -r .terraform_version)"
printf 'Docker: %s\n' "$(docker version --format '{{.Server.Version}}')"
printf 'Node: %s\n' "$(node --version)"
