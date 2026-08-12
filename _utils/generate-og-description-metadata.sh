#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_ROOT="${REPO_ROOT}/reporting-guidelines"
MARKER="# generated-by: og-description-prerender"

remove_generated_sidecars() {
  while IFS= read -r -d '' sidecar; do
    if head -n 1 "${sidecar}" | grep -Fq "${MARKER}"; then
      rm -f "${sidecar}"
    fi
  done < <(find "${TARGET_ROOT}" -type f -name '_metadata.yml' -print0)
}

has_existing_user_sidecar() {
  local sidecar="$1"
  [[ -f "${sidecar}" ]] && ! head -n 1 "${sidecar}" | grep -Fq "${MARKER}"
}

main() {
  local qmd_file=""
  local page_dir=""
  local sidecar=""
  local meta_json=""
  local has_og_description=""
  local description_md=""
  local description_plain=""
  local escaped=""
  local generated_count=0
  local skipped_existing_sidecar=0
  local skipped_existing_og=0
  local skipped_no_description=0
  local processed_count=0
  local total_files=0

  total_files="$(find "${TARGET_ROOT}" -type f -name 'index.qmd' | wc -l | tr -d '[:space:]')"
  echo "Generating OG description sidecars for ${total_files} pages..." >&2

  remove_generated_sidecars

  while IFS= read -r -d '' qmd_file; do
    processed_count=$((processed_count + 1))

    if (( processed_count == 1 || processed_count % 25 == 0 || processed_count == total_files )); then
      echo "Progress: ${processed_count}/${total_files}" >&2
    fi

    page_dir="$(dirname "${qmd_file}")"
    sidecar="${page_dir}/_metadata.yml"

    if has_existing_user_sidecar "${sidecar}"; then
      skipped_existing_sidecar=$((skipped_existing_sidecar + 1))
      continue
    fi

    meta_json="$(ruby -ryaml -rjson -e '
      path = ARGV[0]
      text = File.read(path, encoding: "UTF-8")
      data = {}

      if (m = text.match(/\A---\s*\n(.*?)\n---\s*\n/m))
        begin
          loaded = YAML.safe_load(m[1], permitted_classes: [], aliases: true)
          data = loaded if loaded.is_a?(Hash)
        rescue Psych::Exception
          data = {}
        end
      end

      og_desc = nil
      if data["open-graph"].is_a?(Hash)
        og_desc = data["open-graph"]["description"]
      end

      puts JSON.generate({
        "description" => data["description"],
        "open_graph_description" => og_desc
      })
    ' "${qmd_file}")"

    has_og_description="$(printf '%s' "${meta_json}" | jq -r '.open_graph_description != null')"
    if [[ "${has_og_description}" == "true" ]]; then
      skipped_existing_og=$((skipped_existing_og + 1))
      continue
    fi

    description_md="$(printf '%s' "${meta_json}" | jq -r '.description // ""')"
    if [[ -z "${description_md}" ]]; then
      skipped_no_description=$((skipped_no_description + 1))
      continue
    fi

    description_plain="$(printf '%s' "${description_md}" | quarto pandoc --from markdown --to plain | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
    if [[ -z "${description_plain}" ]]; then
      skipped_no_description=$((skipped_no_description + 1))
      continue
    fi

    escaped="$(printf '%s' "${description_plain}" | jq -Rs .)"

    cat > "${sidecar}" <<EOF
${MARKER}
open-graph:
  description: ${escaped}
EOF

    generated_count=$((generated_count + 1))
  done < <(find "${TARGET_ROOT}" -type f -name 'index.qmd' -print0)

  echo "Finished processing ${processed_count} pages." >&2
  echo "Generated OG sidecars: ${generated_count}" >&2
  echo "Skipped (existing _metadata.yml): ${skipped_existing_sidecar}" >&2
  echo "Skipped (existing open-graph.description): ${skipped_existing_og}" >&2
  echo "Skipped (no description): ${skipped_no_description}" >&2
}

main "$@"