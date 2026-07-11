#!/usr/bin/env bash
set -euo pipefail

task="${1:-all}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
	echo "error: $*" >&2
	exit 1
}

resolve_godot_binary() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s\n' "$GODOT_BIN"
		return
	fi

	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return
	fi

	local macos_candidates=(
		"$HOME/.local/opt/godot/4.7/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot-4.7.app/Contents/MacOS/Godot"
	)
	for macos_binary in "${macos_candidates[@]}"; do
		if [[ -x "$macos_binary" ]]; then
			printf '%s\n' "$macos_binary"
			return
		fi
	done

	shopt -s nullglob
	local linux_candidates=("$HOME"/.local/opt/godot/4.7/Godot_v4.7-stable_linux.*)
	shopt -u nullglob
	if (( ${#linux_candidates[@]} > 0 )); then
		printf '%s\n' "${linux_candidates[0]}"
		return
	fi

	fail "Godot 4.7 stable was not found. Install it from the agent setup guide or set GODOT_BIN."
}

[[ -f "$repo_root/project.godot" ]] || fail "Run this script from a checkout that contains project.godot."
godot_binary="$(resolve_godot_binary)"
[[ -x "$godot_binary" ]] || fail "Godot executable is not executable: $godot_binary"

if ! version="$($godot_binary --version 2>&1)"; then
	fail "Could not read the Godot version from $godot_binary"
fi
[[ "$version" == 4.7.stable.* ]] || fail "Bean Party requires the standard Godot 4.7 stable release. Found: $version"

validate() {
	"$godot_binary" --headless --path "$repo_root" --editor --quit
}

test_suite() {
	"$godot_binary" --headless --path "$repo_root" -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
}

case "$task" in
	validate)
		validate
		;;
	test)
		test_suite
		;;
	all)
		validate
		test_suite
		;;
	*)
		fail "Usage: $0 [validate|test|all]"
		;;
esac
