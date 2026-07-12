# Godot setup for agents

Use this guide when an agent needs to run, validate, or test Bean Party. It is terminal-first: do not rely on the Godot Project Manager, a GUI prompt, a globally configured alias, or a machine-specific repository path.

## Required engine

Bean Party requires the **standard Godot 4.7 stable** editor with GDScript support. Do not use a preview, a later patch release, or the .NET download. The project deliberately pins this release; propose a decision record before changing it.

All archives below are from the [official Godot 4.7 stable archive](https://godotengine.org/download/archive/4.7-stable/). Verify a downloaded archive before extracting it.

## Windows 11

From the repository root, install the exact package non-interactively:

```powershell
winget install --id GodotEngine.GodotEngine --exact --version 4.7 --accept-package-agreements --accept-source-agreements --disable-interactivity
powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 all
```

WinGet can add the `godot` alias only after a new shell starts, and it may not add it without elevation. The runner searches WinGet's user package directory automatically, so the validation command works in the shell that performed the installation. Set `GODOT_BIN` only when the executable is installed somewhere else:

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7-stable_win64.exe"
powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 all
```

## macOS

Download the Universal standard archive into a temporary directory, verify it, and unpack it into a user-owned directory:

```bash
archive="$TMPDIR/Godot_v4.7-stable_macos.universal.zip"
curl --fail --location --output "$archive" "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_macos.universal.zip"
echo "a6708c336f690e0dd8abd3d587d661707f4f33ed436946a3ec000d2fb497fd6c  $archive" | shasum -a 256 -c -
install_dir="$HOME/.local/opt/godot/4.7"
mkdir -p "$install_dir"
unzip -q "$archive" -d "$install_dir"
export GODOT_BIN="$install_dir/Godot.app/Contents/MacOS/Godot"
bash tools/godot.sh all
```

If macOS blocks the downloaded app, remove the quarantine attribute from this specific local copy, then repeat the command:

```bash
xattr -dr com.apple.quarantine "$install_dir/Godot.app"
```

## Linux

Choose the standard archive that matches `uname -m`: use `x86_64` on most desktop and CI machines, or `arm64` on 64-bit ARM systems.

```bash
archive="$HOME/.cache/Godot_v4.7-stable_linux.x86_64.zip"
mkdir -p "$(dirname "$archive")"
curl --fail --location --output "$archive" "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip"
echo "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c  $archive" | sha256sum -c -
install_dir="$HOME/.local/opt/godot/4.7"
mkdir -p "$install_dir"
unzip -q "$archive" -d "$install_dir"
export GODOT_BIN="$install_dir/Godot_v4.7-stable_linux.x86_64"
bash tools/godot.sh all
```

For arm64, substitute `linux.arm64` in the archive name and URL, use checksum `db5aa126353a18fd664818e4f1b9cfffaa77e32d4c9af0ea87e8f028a395a1ed`, and set `GODOT_BIN` to `Godot_v4.7-stable_linux.arm64`.

## Repository commands

The runners accept one task:

| Task | Effect |
| --- | --- |
| `validate` | Imports the project headlessly with `--editor --quit`. |
| `test` | Runs all GUT tests headlessly. |
| `all` | Runs validation first, then tests; use this before opening a pull request. |

Use `tools/godot.ps1 <task>` on Windows and `bash tools/godot.sh <task>` on macOS or Linux. Both runners honor `GODOT_BIN`, then look on PATH and in their documented user-install locations. They exit nonzero if Godot is missing, uses the wrong version, cannot import the project, or has a failing test.

Godot will create `.godot/` when it imports the project. That directory is ignored and must not be committed. If a fresh import is necessary, delete only the repository's `.godot/` directory; do not remove unrelated user files or use a broad cleanup command.

## GDScript quality and repository guards

The formatting, lint, and file-size checks require Python and the pinned development dependency in `requirements-dev.txt`. Create a repository-local virtual environment once:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-dev.txt
.\tools\quality.ps1 check
```

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
bash tools/quality.sh check
```

The runners automatically use the repository-local virtual environment when present. `check` verifies `gdformat`, runs `gdlint`, enforces the 5 MiB per-file repository limit, and runs the guard's unit tests. Use `format` instead of `check` to rewrite project-owned GDScript before running the same remaining checks. Vendored code under `addons/` is excluded.

After setup, use the [runtime debug harness guide](runtime-debug-harnesses.md) to exercise the main local/network architecture proofs or the separate local minigame harness.

## Adding tests

GUT 9.7.1 is the project test framework. Add deterministic GDScript tests beneath `tests/`, using `extends GutTest`; put minigame-local behavior inside that minigame's `tests/` directory. The standard configuration discovers both locations and also validates minigame boundaries and relative Markdown links. Every behavior change should run the full `all` command and include tests or explain why automated coverage is not appropriate.

The vendored add-on and its MIT license are recorded in [the third-party notices](../../THIRD_PARTY_NOTICES.md) and [Decision 0002](../decisions/0002-gut-testing.md).
