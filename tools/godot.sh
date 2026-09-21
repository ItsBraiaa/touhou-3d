#!/usr/bin/env sh
# Runs the project's Godot 4.7.2 binary and forwards every argument unchanged.
# POSIX mirror of tools/godot.ps1 for hosts without PowerShell.
#
# Resolution order: $GODOT_BIN, then the verified local path below.
# Prints "Using Godot: <path>" to stderr once and exits with Godot's own exit code.
# Exit code 2 means no binary was found at either location.

default_godot="$HOME/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64"

godot=""
if [ -n "${GODOT_BIN:-}" ]; then
    if [ -f "$GODOT_BIN" ]; then
        godot="$GODOT_BIN"
    else
        echo "godot.sh: GODOT_BIN is set but no file exists there: $GODOT_BIN" >&2
    fi
fi
if [ -z "$godot" ] && [ -f "$default_godot" ]; then
    godot="$default_godot"
fi
if [ -z "$godot" ]; then
    echo "godot.sh: Godot binary not found. Looked at:" >&2
    echo "  1. GODOT_BIN environment variable: ${GODOT_BIN:-(not set)}" >&2
    echo "  2. Default path: $default_godot" >&2
    echo "Set GODOT_BIN to a Godot 4.7.2 executable or place it at the default path." >&2
    exit 2
fi

echo "Using Godot: $godot" >&2
exec "$godot" "$@"
