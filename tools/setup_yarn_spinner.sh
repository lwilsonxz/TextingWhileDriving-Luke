#!/usr/bin/env bash
# Installs the pinned Yarn Spinner for Godot (GDScript) addon into one or more Godot projects.
# The addon is not committed: its licence (YSPL) forbids redistributing unmodified source.
#
# Usage: tools/setup_yarn_spinner.sh [project_dir ...]
#        (defaults to every directory in the repo that contains a project.godot)
set -euo pipefail

YARN_REPO="https://github.com/YarnSpinnerTool/YarnSpinner-Godot-GDScript"
YARN_COMMIT="b4852f83ee9295fe03fe6a8c623e8e46e0446d86" # Early Access 3.2 (2026-10-01)

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cache="$repo_root/.cache/yarn-spinner/$YARN_COMMIT"

if [ ! -f "$cache/addons/yarn_spinner/plugin.cfg" ]; then
	rm -rf "$cache"
	mkdir -p "$cache"
	git -C "$cache" init -q
	git -C "$cache" remote add origin "$YARN_REPO"
	git -C "$cache" fetch -q --depth 1 origin "$YARN_COMMIT"
	git -C "$cache" checkout -q FETCH_HEAD
fi

if [ "$#" -eq 0 ]; then
	mapfile -t projects < <(find "$repo_root" -name project.godot -not -path '*/.cache/*' -not -path '*/addons/*' -exec dirname {} \;)
else
	projects=("$@")
fi

for project in "${projects[@]}"; do
	rm -rf "$project/addons/yarn_spinner"
	mkdir -p "$project/addons"
	cp -R "$cache/addons/yarn_spinner" "$project/addons/yarn_spinner"
	echo "Installed Yarn Spinner ($YARN_COMMIT) into $project/addons/yarn_spinner"
done
