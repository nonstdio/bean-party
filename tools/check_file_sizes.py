#!/usr/bin/env python3
"""Reject tracked or unignored repository files above the configured size limit."""

from __future__ import annotations

import argparse
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
from typing import Iterable


DEFAULT_LIMIT_MIB = 5
MIB = 1024 * 1024


def normalize_relative_path(value: str) -> str:
	"""Return a safe, repository-relative path with POSIX separators."""
	normalized = value.replace("\\", "/").strip()
	path = PurePosixPath(normalized)
	if not normalized or path.is_absolute() or ".." in path.parts:
		raise ValueError(f"Invalid repository-relative path: {value!r}")
	return path.as_posix()


def load_allowlist(path: Path) -> set[str]:
	"""Load exact paths, ignoring comments and blank lines."""
	if not path.exists():
		return set()

	entries: set[str] = set()
	for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
		value = line.split("#", maxsplit=1)[0].strip()
		if not value:
			continue
		try:
			entries.add(normalize_relative_path(value))
		except ValueError as error:
			raise ValueError(f"{path}:{line_number}: {error}") from error
	return entries


def list_repository_files(repo_root: Path) -> list[str]:
	"""List tracked and untracked, nonignored worktree files using NUL-safe Git output."""
	result = subprocess.run(
		[
			"git",
			"-C",
			str(repo_root),
			"ls-files",
			"-z",
			"--cached",
			"--others",
			"--exclude-standard",
		],
		check=True,
		stdout=subprocess.PIPE,
	)
	paths = {
		normalize_relative_path(os.fsdecode(raw_path))
		for raw_path in result.stdout.split(b"\0")
		if raw_path
	}
	return sorted(paths)


def find_oversized_files(
	repo_root: Path,
	relative_paths: Iterable[str],
	limit_bytes: int,
	allowlist: set[str],
) -> list[tuple[str, int]]:
	"""Return non-allowlisted files whose worktree size exceeds the limit."""
	oversized: list[tuple[str, int]] = []
	for relative_path in relative_paths:
		normalized = normalize_relative_path(relative_path)
		path = repo_root / Path(normalized)
		if not path.exists() and not path.is_symlink():
			continue
		size = path.lstat().st_size
		if size > limit_bytes and normalized not in allowlist:
			oversized.append((normalized, size))
	return sorted(oversized)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"--limit-mib",
		type=int,
		default=DEFAULT_LIMIT_MIB,
		help=f"maximum bytes per file in MiB (default: {DEFAULT_LIMIT_MIB})",
	)
	parser.add_argument(
		"--repo-root",
		type=Path,
		default=Path(__file__).resolve().parent.parent,
		help=argparse.SUPPRESS,
	)
	parser.add_argument(
		"--allowlist",
		type=Path,
		default=None,
		help=argparse.SUPPRESS,
	)
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	if args.limit_mib <= 0:
		print("error: --limit-mib must be positive", file=sys.stderr)
		return 2

	repo_root = args.repo_root.resolve()
	allowlist_path = args.allowlist or repo_root / "tools" / "file-size-allowlist.txt"
	try:
		allowlist = load_allowlist(allowlist_path)
		relative_paths = list_repository_files(repo_root)
		oversized = find_oversized_files(
			repo_root,
			relative_paths,
			args.limit_mib * MIB,
			allowlist,
		)
	except (OSError, subprocess.CalledProcessError, ValueError) as error:
		print(f"error: file-size check could not run: {error}", file=sys.stderr)
		return 2

	if oversized:
		print(f"Files exceed the {args.limit_mib} MiB repository limit:", file=sys.stderr)
		for relative_path, size in oversized:
			print(f"  {relative_path}: {size / MIB:.2f} MiB", file=sys.stderr)
		print(
			"Reduce the file or obtain maintainer approval for an exact-path exception in "
			"tools/file-size-allowlist.txt.",
			file=sys.stderr,
		)
		return 1

	print(
		f"File-size check passed: {len(relative_paths)} files are at or below "
		f"{args.limit_mib} MiB, excluding {len(allowlist)} approved path(s)."
	)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
