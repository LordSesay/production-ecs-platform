#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: %s <aws-region> <web-repository-url> <api-repository-url> <commit-sha>\n' "$0" >&2
}

if (($# != 4)); then
  usage
  exit 64
fi

aws_region=$1
web_repository=$2
api_repository=$3
commit_sha=$4

if [[ ! ${commit_sha} =~ ^[0-9a-f]{7,40}$ ]]; then
  printf 'commit-sha must be 7-40 lowercase hexadecimal characters.\n' >&2
  exit 64
fi

image_tag="sha-${commit_sha}"
registry="${web_repository%%/*}"
web_image="${web_repository}:${image_tag}"
api_image="${api_repository}:${image_tag}"

for command_name in aws docker; do
  command -v "${command_name}" >/dev/null 2>&1 || {
    printf '%s is required.\n' "${command_name}" >&2
    exit 1
  }
done

aws ecr get-login-password --region "${aws_region}" |
  docker login --username AWS --password-stdin "${registry}"

if [[ ${SKIP_BUILD:-false} != "true" ]]; then
  docker build \
    --label "org.opencontainers.image.revision=${commit_sha}" \
    --tag "${web_image}" \
    apps/web

  docker build \
    --label "org.opencontainers.image.revision=${commit_sha}" \
    --tag "${api_image}" \
    apps/api
fi

push_if_absent() {
  local repository_url=$1
  local image_uri=$2
  local repository_name="${repository_url#*/}"

  if aws ecr describe-images \
    --region "${aws_region}" \
    --repository-name "${repository_name}" \
    --image-ids "imageTag=${image_tag}" >/dev/null 2>&1; then
    printf 'Reusing existing immutable image %s\n' "${image_uri}"
    return
  fi

  docker push "${image_uri}"
}

push_if_absent "${web_repository}" "${web_image}"
push_if_absent "${api_repository}" "${api_image}"

printf 'WEB_IMAGE_URI=%s\n' "${web_image}"
printf 'API_IMAGE_URI=%s\n' "${api_image}"
