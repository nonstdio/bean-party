#!/usr/bin/env bash
set -euo pipefail

task="${1:-check}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo_root/assets/source/standard/characters/bean-static-prototype.blend"
output_file="$repo_root/assets/standard/characters/bean-static-prototype.glb"
script_file="$repo_root/tools/blender/bean_static_prototype.py"
required_blender_version="5.1.2"

if [[ -n "${BLENDER_BIN:-}" ]]; then
	blender_bin="$BLENDER_BIN"
elif command -v blender >/dev/null 2>&1; then
	blender_bin="$(command -v blender)"
else
	echo "error: Blender $required_blender_version was not found; set BLENDER_BIN" >&2
	exit 1
fi

if ! version_output="$("$blender_bin" --version 2>&1)"; then
	echo "error: Blender version probe failed: $version_output" >&2
	exit 1
fi
version="${version_output%%$'\n'*}"
[[ "$version" == "Blender $required_blender_version" ]] || {
	echo "error: standard assets require Blender $required_blender_version; found $version" >&2
	exit 1
}

export_asset() {
	local target="$1"
	"$blender_bin" --background "$source_file" --python "$script_file" -- \
		--mode export --output "$target"
}

case "$task" in
	build)
		"$blender_bin" --background --python "$script_file" -- \
			--mode build --source "$source_file" --output "$output_file"
		;;
	export)
		export_asset "$output_file"
		;;
	check)
		[[ -f "$source_file" ]] || { echo "error: missing $source_file" >&2; exit 1; }
		[[ -f "$output_file" ]] || { echo "error: missing $output_file" >&2; exit 1; }
		temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/bean-party-assets.XXXXXX")"
		temp_output="$temp_dir/bean-static-prototype.glb"
		trap 'rm -rf "$temp_dir"' EXIT
		export_asset "$temp_output"
		cmp -s "$output_file" "$temp_output" || {
			echo "error: committed GLB is stale; run tools/assets.sh export" >&2
			exit 1
		}
		;;
	*)
		echo "usage: tools/assets.sh [build|export|check]" >&2
		exit 1
		;;
esac
