#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SLUG_SCRIPT="${SCRIPT_DIR}/create-slug.sh"
BLANK_TEMPLATE="${REPO_ROOT}/reporting-guidelines/under-development/_blank_rg.qmd"
TARGET_ROOT="${REPO_ROOT}/reporting-guidelines/under-development"

fail() {
	echo "Error: $*" >&2
	exit 1
}

escape_yaml() {
	printf '%s' "$1" | sed 's/"/\\"/g'
}

main() {
	local title=""
	local contact_name=""
	local contact_email=""
	local slug=""
	local today=""	
    local year_registered=""	
    local target_dir=""
	local target_file=""
	local yaml_block=""
	local rendered_template=""

	[[ -x "${SLUG_SCRIPT}" ]] || fail "Slug script is missing or not executable: ${SLUG_SCRIPT}"
	[[ -f "${BLANK_TEMPLATE}" ]] || fail "Blank template not found: ${BLANK_TEMPLATE}"

	read -r -p "RG title: " title
	[[ -n "${title}" ]] || fail "RG title cannot be blank"

	read -r -p "Contact name: " contact_name
	[[ -n "${contact_name}" ]] || fail "Contact name cannot be blank"

	read -r -p "Contact email: " contact_email
	[[ -n "${contact_email}" ]] || fail "Contact email cannot be blank"

	slug="$(${SLUG_SCRIPT} "${title}")"
	[[ -n "${slug}" ]] || fail "Failed to generate slug from title"

	today="$(date '+%-d %B %Y')"
	year_registered="$(date '+%Y')"
	target_dir="${TARGET_ROOT}/${slug}"
	target_file="${target_dir}/index.qmd"

	[[ ! -e "${target_dir}" ]] || fail "Target directory already exists: ${target_dir}"

	mkdir -p "${target_dir}"
	cp "${BLANK_TEMPLATE}" "${target_file}"

	yaml_block=$(cat <<EOF
title: "$(escape_yaml "${title}")"
contact-name: "$(escape_yaml "${contact_name}")"
contact-email: "$(escape_yaml "${contact_email}")"
date-registered: "${today}"
year-registered: ${year_registered}
EOF
)

	rendered_template="$(sed \
		-e "s|#YAML|${yaml_block//$'\n'/\\
}|" \
		-e '/^#DESCRIPTION$/d' \
		"${target_file}")"

	printf '%s\n' "${rendered_template}" > "${target_file}"

	echo "Created new index file: ${target_file}"
}

main "$@"
