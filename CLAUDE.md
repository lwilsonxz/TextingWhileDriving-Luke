# CLAUDE.md

## Repository rules

- **Fork only.** This repo is a fork of a public upstream repo. Never open PRs, push, or comment
  against the upstream repo without explicit permission. All PRs target this fork's `main`
  (`lwilsonxz/TextingWhileDriving-Luke`).
- **Descriptive branch names**, e.g. `roadmap-doc` or `phone-typing-input`. One branch per piece of work,
  merged to `main` by PR (branches are auto-deleted on merge).

## Project

- Godot 4.6.3 project in `TextingWhileDriving/` (game code in `game/`, dialogue in `dialogue/`).
  GDScript only (no C#), Windows only. Setup steps are in the root README.
- The Yarn Spinner addon (`addons/yarn_spinner/`) is never committed (licence). Install it with
  `tools/setup_yarn_spinner.sh`. Bump the pinned commit there to upgrade.
- Before pushing, run the checks in the README's "Checks" section (dialogue validator, scene smoke
  check). CI runs both.
- **Art: use existing assets; don't make your own.** If something visual has to be made or changed
  (a UI, a model, a material, a sky...), mark it `ART PLACEHOLDER` in the code and list it in
  `docs/ART_PLACEHOLDERS.md`, so human artists can replace it.
- Plans and decisions live in `docs/ROADMAP.md`. Check its Decisions table before proposing changes
  to settled choices.
