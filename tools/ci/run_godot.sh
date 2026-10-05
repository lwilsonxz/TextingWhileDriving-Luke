#!/usr/bin/env bash
# Runs a Godot command for CI and fails if it fails, times out, or prints any
# GDScript error. The exit code alone isn't enough: a runtime error inside game
# code during a test is printed but doesn't change the exit code, and a script
# that errors before calling quit() hangs instead of exiting.
#
# Usage: tools/ci/run_godot.sh godot --headless --script tools/validate_dialogue.gd
set -uo pipefail

log="$(mktemp)"
timeout "${GODOT_TIMEOUT:-600}" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if [ "$status" -eq 124 ]; then
	echo "::error::Timed out after ${GODOT_TIMEOUT:-600}s: $*"
	exit 1
fi
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then
	echo "::error::GDScript error while running: $* (see the log above)"
	exit 1
fi
exit "$status"
