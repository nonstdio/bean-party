#!/usr/bin/env bash
set -euo pipefail

slug="${1:-}"
display_name="${2:-}"
if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || [[ -z "$display_name" ]]; then
	echo "Usage: bash tools/new-minigame.sh <lowercase-kebab-slug> <display-name>" >&2
	exit 1
fi
if [[ "$display_name" == *'"'* || "$display_name" == *'\'* || "$display_name" == *$'\n'* ]]; then
	echo "Display name must not contain a double quote, backslash, or newline." >&2
	exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_root="$repo_root/minigames/_template"
target_root="$repo_root/minigames/$slug"
[[ -d "$template_root" ]] || { echo "Minigame template was not found: $template_root" >&2; exit 1; }
[[ ! -e "$target_root" ]] || { echo "A minigame folder already exists: $target_root" >&2; exit 1; }

cp -R "$template_root" "$target_root"
script_slug="${slug//-/_}"
node_name=""
IFS='-' read -ra slug_parts <<< "$slug"
for part in "${slug_parts[@]}"; do
	node_name+="${part^}"
done

while IFS= read -r -d '' template_file; do
	output_file="${template_file%.tmpl}"
	if [[ "$output_file" == */scripts/main.gd ]]; then
		output_file="${output_file%main.gd}${script_slug}.gd"
	fi
	escaped_display_name="${display_name//\\/\\\\}"
	escaped_display_name="${escaped_display_name//&/\\&}"
	escaped_display_name="${escaped_display_name//|/\\|}"
	sed \
		-e "s|__SLUG__|$slug|g" \
		-e "s|__DISPLAY_NAME__|$escaped_display_name|g" \
		-e "s|__SCRIPT_SLUG__|$script_slug|g" \
		-e "s|__NODE_NAME__|$node_name|g" \
		"$template_file" > "$output_file"
	rm "$template_file"
done < <(find "$target_root" -type f -name '*.tmpl' -print0)

echo "Created minigame scaffold at minigames/$slug"
