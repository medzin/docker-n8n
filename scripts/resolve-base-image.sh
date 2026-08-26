#!/bin/bash
set -e

# Resolves the base image a given n8n version was built on, so we can lift a
# matching `apk` binary from it (see Dockerfile). n8n pins this in its own
# base Dockerfile, so we read the FROM line at the matching release tag - this
# stays correct across the build matrix even when n8n bumps its base.

VERSION="$1"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <n8n-version>" >&2
  exit 1
fi

REPO="n8n-io/n8n"
BASE_DOCKERFILE="docker/images/n8n-base/Dockerfile"
REF="n8n@${VERSION}"

echo "Resolving base image for n8n ${VERSION}..." >&2

# `|| true` so a fetch failure falls through to the friendly check below
# instead of aborting under `set -e` with a bare curl exit code.
CONTENT=$(curl -sf "https://raw.githubusercontent.com/${REPO}/${REF}/${BASE_DOCKERFILE}" || true)

if [ -z "$CONTENT" ]; then
  echo "Could not fetch ${BASE_DOCKERFILE} at ${REF}" >&2
  exit 1
fi

# Extract the first FROM token, resolving an ARG default when necessary.
FROM_IMAGE=$(echo "$CONTENT" | grep -m1 -E '^FROM ' | awk '{print $2}')

if [ -z "$FROM_IMAGE" ]; then
  echo "No FROM line found in ${BASE_DOCKERFILE} at ${REF}" >&2
  exit 1
fi

BASE_IMAGE=$FROM_IMAGE

case "$BASE_IMAGE" in
  '${'*'}')
    ARG_NAME=${BASE_IMAGE#'${'}
    ARG_NAME=${ARG_NAME%'}'}

    case "$ARG_NAME" in
      ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
        echo "Unsupported FROM variable ${BASE_IMAGE} in ${BASE_DOCKERFILE} at ${REF}" >&2
        exit 1
        ;;
    esac

    BASE_IMAGE=$(echo "$CONTENT" | awk -v name="$ARG_NAME" '
      $1 == "FROM" { exit }
      $1 == "ARG" && index($2, name "=") == 1 {
        print substr($2, length(name) + 2)
        exit
      }
    ')
    ;;
esac

if [ -z "$BASE_IMAGE" ]; then
  echo "No default found for ARG ${ARG_NAME} in ${BASE_DOCKERFILE} at ${REF}" >&2
  exit 1
fi

echo "$BASE_IMAGE"
