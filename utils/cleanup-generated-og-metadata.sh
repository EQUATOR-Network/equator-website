#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="${REPO_ROOT}/reporting-guidelines"
MARKER="# generated-by: og-description-prerender"

removed=0

while IFS= read -r -d '' sidecar; do
  if head -n 1 "${sidecar}" | grep -Fq "${MARKER}"; then
    rm -f "${sidecar}"
    removed=$((removed + 1))
  fi
done < <(find "${TARGET_ROOT}" -type f -name '_metadata.yml' -print0)

echo "Removed generated OG sidecars: ${removed}" >&2