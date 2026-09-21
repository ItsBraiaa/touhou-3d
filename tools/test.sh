#!/usr/bin/env sh
# Runs the headless GDScript test suite (tests/run_tests.gd) through tools/godot.sh.
# POSIX mirror of tools/test.ps1 for hosts without PowerShell.
#
# Usage: tools/test.sh [-f <substring>] [-i] [runner args...]
#   -f <substring>  forwarded as --filter=<substring> (matched against "<file>::<method>")
#   -i              force the headless editor import (class-cache refresh) first
#   anything else   forwarded to the runner after "--", for example --timeout=60
#
# Exits with Godot's exit code: 0 when every discovered test passed, 1 otherwise.
# Scripts that name class_name types resolve only through Godot's class cache in
# .godot/, so this script refreshes it with a headless import (about three seconds)
# when the cache is missing, when -i is given, or when a .gd file under the code
# folders is newer than the last import this script performed (.godot/test_import.stamp).

set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
godot_wrapper="$root/tools/godot.sh"
cache_dir="$root/.godot"
class_cache="$cache_dir/global_script_class_cache.cfg"
stamp="$cache_dir/test_import.stamp"

filter=""
force_import=0
while [ $# -gt 0 ]; do
    case "$1" in
        -f|--filter) filter="$2"; shift 2 ;;
        -i|--import) force_import=1; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

import_needed() {
    [ -f "$class_cache" ] || return 0
    [ -f "$stamp" ] || return 0
    for dir in scripts tests tools scenes content addons; do
        [ -d "$root/$dir" ] || continue
        if [ -n "$(find "$root/$dir" -name '*.gd' -newer "$stamp" -print -quit)" ]; then
            return 0
        fi
    done
    return 1
}

if [ "$force_import" -eq 1 ] || import_needed; then
    echo "test.sh: refreshing the Godot class cache (headless import)..." >&2
    "$godot_wrapper" --headless --path "$root" --import
    status=$?
    if [ "$status" -ne 0 ]; then
        echo "test.sh: import failed with exit code $status" >&2
        exit "$status"
    fi
    mkdir -p "$cache_dir"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$stamp"
fi

set -- --headless --path "$root" --script res://tests/run_tests.gd -- ${filter:+"--filter=$filter"} "$@"
exec "$godot_wrapper" "$@"
