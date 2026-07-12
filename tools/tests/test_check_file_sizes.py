from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))

from check_file_sizes import find_oversized_files, list_repository_files, load_allowlist


class CheckFileSizesTest(unittest.TestCase):
	def test_file_equal_to_limit_passes_and_larger_file_fails(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "exact.bin").write_bytes(b"a" * 8)
			(root / "large.bin").write_bytes(b"b" * 9)

			oversized = find_oversized_files(
				root,
				["exact.bin", "large.bin"],
				limit_bytes=8,
				allowlist=set(),
			)

			self.assertEqual([("large.bin", 9)], oversized)

	def test_exact_allowlist_path_exempts_only_that_file(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "allowed.bin").write_bytes(b"a" * 9)
			(root / "blocked.bin").write_bytes(b"b" * 9)
			allowlist_path = root / "allowlist.txt"
			allowlist_path.write_text("# reviewed\nallowed.bin\n", encoding="utf-8")

			oversized = find_oversized_files(
				root,
				["allowed.bin", "blocked.bin"],
				limit_bytes=8,
				allowlist=load_allowlist(allowlist_path),
			)

			self.assertEqual([("blocked.bin", 9)], oversized)

	def test_parent_path_is_rejected_in_allowlist(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			allowlist_path = Path(directory) / "allowlist.txt"
			allowlist_path.write_text("../outside.bin\n", encoding="utf-8")

			with self.assertRaisesRegex(ValueError, "Invalid repository-relative path"):
				load_allowlist(allowlist_path)

	def test_git_listing_includes_untracked_files_and_skips_ignored_files(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			subprocess.run(["git", "init", "--quiet", str(root)], check=True)
			(root / ".gitignore").write_text("ignored.bin\n", encoding="utf-8")
			(root / "tracked.bin").write_bytes(b"tracked")
			(root / "untracked.bin").write_bytes(b"untracked")
			(root / "ignored.bin").write_bytes(b"ignored")
			subprocess.run(
				["git", "-C", str(root), "add", ".gitignore", "tracked.bin"],
				check=True,
			)

			paths = set(list_repository_files(root))

			self.assertIn("tracked.bin", paths)
			self.assertIn("untracked.bin", paths)
			self.assertNotIn("ignored.bin", paths)


if __name__ == "__main__":
	unittest.main()
