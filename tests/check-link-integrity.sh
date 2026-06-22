#!/usr/bin/env bash

set -euo pipefail

SITE_DIR="${1:-_site}"

if [[ ! -d "${SITE_DIR}" ]]; then
  echo "Error: Site directory not found: ${SITE_DIR}" >&2
  echo "Fix: Run 'quarto render' (or 'make publish') first, or pass a valid directory." >&2
  exit 2
fi

html_files=()
while IFS= read -r -d '' file; do
  html_files+=("${file}")
done < <(find "${SITE_DIR}" -type f -name '*.html' -print0)

if [[ ${#html_files[@]} -eq 0 ]]; then
  echo "Error: No HTML files found under ${SITE_DIR}" >&2
  echo "Fix: Render the site before running this checker." >&2
  exit 2
fi

fail_count=0

report_failure() {
  local file="$1"
  local line="$2"
  local issue="$3"
  local value="$4"
  local fix="$5"

  fail_count=$((fail_count + 1))
  printf 'FAIL %s:%s\n' "${file}" "${line}"
  printf '  Issue: %s\n' "${issue}"
  printf '  Value: %s\n' "${value}"
  printf '  Fix: %s\n\n' "${fix}"
}

is_external_url() {
  local url="$1"
  [[ "${url}" =~ ^https?:// ]] || \
  [[ "${url}" =~ ^// ]] || \
  [[ "${url}" =~ ^mailto: ]] || \
  [[ "${url}" =~ ^tel: ]] || \
  [[ "${url}" =~ ^javascript: ]] || \
  [[ "${url}" =~ ^data: ]] || \
  [[ "${url}" =~ ^about: ]]
}

anchor_exists_in_file() {
  local file="$1"
  local anchor="$2"

  grep -Fq "id=\"${anchor}\"" "${file}" || \
  grep -Fq "id='${anchor}'" "${file}" || \
  grep -Fq "name=\"${anchor}\"" "${file}" || \
  grep -Fq "name='${anchor}'" "${file}"
}

local_target_exists() {
  local source_file="$1"
  local url="$2"

  local no_fragment="${url%%#*}"
  local base_path="${no_fragment%%\?*}"
  local target=""

  if [[ -z "${base_path}" ]]; then
    return 0
  fi

  if [[ "${base_path}" == /* ]]; then
    target="${SITE_DIR}/${base_path#/}"
  else
    target="$(dirname "${source_file}")/${base_path}"
  fi

  if [[ -e "${target}" ]]; then
    return 0
  fi

  if [[ -d "${target}" ]] && [[ -e "${target}/index.html" ]]; then
    return 0
  fi

  if [[ "${target}" != *.* ]]; then
    if [[ -e "${target}.html" ]] || [[ -e "${target}/index.html" ]]; then
      return 0
    fi
  fi

  return 1
}

# Extract href/src attributes with line numbers.
while IFS=$'\t' read -r file line attr value; do
  [[ -n "${value}" ]] || continue

  if [[ "${value}" == "" ]]; then
    report_failure \
      "${file}" \
      "${line}" \
      "Empty ${attr} attribute" \
      "${attr}=\"\"" \
      "Provide a valid URL/path or remove the attribute if unused."
    continue
  fi

  if is_external_url "${value}"; then
    continue
  fi

  if [[ "${value}" == \#* ]]; then
    local_anchor="${value#\#}"
    if [[ -n "${local_anchor}" ]] && ! anchor_exists_in_file "${file}" "${local_anchor}"; then
      report_failure \
        "${file}" \
        "${line}" \
        "Broken same-page anchor" \
        "${value}" \
        "Add an element with id='${local_anchor}' (or name='${local_anchor}') in the same file, or update the link target."
    fi
    continue
  fi

  if ! local_target_exists "${file}" "${value}"; then
    report_failure \
      "${file}" \
      "${line}" \
      "Broken local ${attr} target" \
      "${value}" \
      "Ensure the referenced file exists in _site, or fix the relative/absolute path."
  fi
done < <(
  perl -ne '
    while (/(href|src)\s*=\s*("([^"]*)"|'"'"'([^'"'"']*)'"'"')/gi) {
      my $attr = $1;
      my $value = defined $3 ? $3 : $4;
      print "$ARGV\t$.\t$attr\t$value\n";
    }
  ' "${html_files[@]}"
)

if (( fail_count > 0 )); then
  exit 1
fi

echo "No link integrity issues found in ${SITE_DIR}."
