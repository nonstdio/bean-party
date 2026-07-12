#!/usr/bin/env bash
set -euo pipefail

task="${1:-check}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
	echo "error: $*" >&2
	exit 1
}

case "$task" in
	check|format) ;;
	*) fail "Usage: bash tools/quality.sh [check|format]" ;;
esac

if [[ -x "$repo_root/.venv/bin/python" ]]; then
	python="$repo_root/.venv/bin/python"
elif [[ -x "$repo_root/.venv/Scripts/python.exe" ]]; then
	python="$repo_root/.venv/Scripts/python.exe"
elif command -v python3 >/dev/null 2>&1; then
	python="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
	python="$(command -v python)"
else
	fail "Python 3 was not found. Follow docs/guides/godot-setup.md to install the quality tools."
fi

cd "$repo_root"
if ! "$python" -c 'import gdtoolkit' >/dev/null 2>&1; then
	fail "gdtoolkit is unavailable. Install it with '.venv/bin/python -m pip install -r requirements-dev.txt'."
fi

paths=(scripts minigames tests)
if [[ "$task" == "check" ]]; then
	"$python" -m gdtoolkit.formatter --check "${paths[@]}"
else
	"$python" -m gdtoolkit.formatter "${paths[@]}"
fi
"$python" -m gdtoolkit.linter "${paths[@]}"
"$python" tools/check_file_sizes.py
"$python" -m unittest discover -s tools/tests -p 'test_*.py'
