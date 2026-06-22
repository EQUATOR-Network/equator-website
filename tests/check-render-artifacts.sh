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
done < <(find "${SITE_DIR}" -type f -name '*.html' ! -path "${SITE_DIR}/site_libs/*" -print0)

if [[ ${#html_files[@]} -eq 0 ]]; then
  echo "Error: No HTML files found under ${SITE_DIR}" >&2
  echo "Fix: Render the site before running this checker." >&2
  exit 2
fi

fail_count=0

report_matches() {
  local mode="$1"
  local pattern="$2"
  local issue="$3"
  local fix="$4"

  local grep_args=(-nH)
  if [[ "${mode}" == "fixed" ]]; then
    grep_args+=(-F)
  else
    grep_args+=(-E)
  fi

  while IFS= read -r match; do
    local file="${match%%:*}"
    local rest="${match#*:}"
    local line="${rest%%:*}"
    local snippet="${rest#*:}"

    fail_count=$((fail_count + 1))
    printf 'FAIL %s:%s\n' "${file}" "${line}"
    printf '  Issue: %s\n' "${issue}"
    printf '  Value: %s\n' "${snippet}"
    printf '  Fix: %s\n\n' "${fix}"
  done < <(grep "${grep_args[@]}" -- "${pattern}" "${html_files[@]}" || true)
}

report_matches \
  fixed \
  "?meta" \
  "Possible unresolved metadata placeholder" \
  "Check the source qmd for missing metadata keys or incorrect shortcode usage (for example {{< meta field >}} with a missing field)."

report_matches \
  regex \
  "\\?invalid[[:space:]-]+meta" \
  "Quarto invalid metadata placeholder found" \
  "Fix invalid/missing metadata keys or shortcode arguments in source qmd so Quarto can resolve the value during render."

report_matches \
  regex \
  "\[[^][]+\][[:space:]]+\((https?://|/|\./|#|mailto:)[^)]+\)" \
  "Possible malformed Markdown link token" \
  "Fix malformed markdown links in source files to use [text](url) with no space between ] and (."

report_matches \
  regex \
  "\[[^][]+\]\((https?://|/|\./|#|mailto:)[^)]+\)" \
  "Raw Markdown link syntax leaked into HTML" \
  "Ensure this content is parsed as markdown (not stringified metadata) and confirm link syntax is valid in the source qmd/yaml."

report_matches \
  fixed \
  ":::" \
  "Quarto fenced div marker leaked into rendered HTML" \
  "Check fenced div blocks in source qmd and ensure every opening ::: has a matching closing :::."

report_matches \
  fixed \
  "{{<" \
  "Unresolved Quarto shortcode in rendered HTML" \
  "Verify shortcode syntax and confirm required extensions/filters are enabled in _quarto.yml."

report_matches \
  fixed \
  "{{%" \
  "Unresolved template/shortcode marker in rendered HTML" \
  "Check source template syntax and ensure the corresponding renderer/extension runs during build."

report_matches \
  fixed \
  "![" \
  "Raw Markdown image syntax leaked into HTML" \
  "Fix source markdown image syntax and ensure the content is being parsed as markdown rather than emitted as plain text."

report_matches \
  regex \
  "^---$" \
  "Possible front matter fence leaked into rendered output" \
  "Ensure YAML front matter is at the top of the source qmd and correctly delimited so it is parsed, not rendered."

report_matches \
  regex \
  "mailto:[[:space:]]" \
  "Malformed mailto link with whitespace after colon" \
  "Use mailto:address@example.com with no space after the colon."

report_matches \
  fixed \
  "�" \
  "Replacement character found (possible encoding issue)" \
  "Check source file encoding (UTF-8), input transformations, and slug/transliteration steps that may be dropping characters."

if (( fail_count > 0 )); then
  exit 1
fi

echo "No markdown/render artifact issues found in ${SITE_DIR}."
