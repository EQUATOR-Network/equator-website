#!/usr/bin/env bash

# Usage: slugify "Some String With Punctuation!"
slugify() {
    local input="$*"
    echo "$input" \
        | iconv -t ASCII//TRANSLIT \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9 -]//g' \
        | sed -E 's/[[:space:]]+/-/g' \
        | sed -E 's/-+/-/g' \
        | sed -E 's/^-|-$//g'
}

# If run directly (not sourced), pass all arguments to the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    slugify "$@"
fi
