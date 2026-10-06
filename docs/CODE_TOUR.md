# Code tour

A map of the code for reviewers: what each part does, how the parts connect, and a suggested reading
order. Every script starts with a comment saying what it's for; this page shows how they fit together.

All game code is GDScript in `TextingWhileDriving/` (paths below are relative to it). Tools and
tests are in `tools/` at the repo root.

---

## The car

```
Doge.tscn  (the car you drive; BaseCar.tscn plus the Doge model)
├── BaseCar.gd        driving: controls → engine force, brakes, steering
├── FirstPersonCamera CarCamera (Camera3D.gd): road / rear / window / phone views
├── PhoneMount        phone_mount.gd: where the phone sits; aims the phone view at it
│   └── Phone         phone.tscn: 2D screen drawn onto a quad (old typing prototype for now)
└── Hud               speed and "TRAFFIC VIOLATION!" labels
```

- **`game/car/BaseCar.gd`:** read `_physics_process` top to bottom. Every tuning value is an
  `@export` at the top, with a comment on what it does; the defaults give realistic car numbers.
- **`game/car/Camera3D.gd` (`CarCamera`):** views are position + rotation (+ zoom) pairs the camera
  glides between. `is_looking_at_phone()` and `view_changed` are what later distraction mechanics
  will use.
- **`game/car/phone_mount.gd`:** the five phone placements (F7 cycles them).
- **`game/settings.gd`:** playtest options saved between sessions (F6/F7), autoloaded as `Settings`.
- **`game/global.gd`:** one flag, `is_driving` (F5 debug toggle).

## Levels

- **`game/levels/test_course.tscn`:** the main scene. Roads are a GridMap painted from the road kit in
  `game/world/models/roads-v4.tres`.
- **`game/rules/course.gd`:** checkpoints in order, finish line, timer. Its signals are where level
  flow (B4) will hook in.
- **`game/rules/stopSign.gd`:** the 2024 stop sign rule. Its header comment lists known limits;
  roadmap B3 generalises it.
- **`game/levels/main.tscn`:** the old ramps sandbox.

## Conversations (the dialogue pipeline)

```
writers' .yarn files ──(Yarn Spinner plugin compiles on import)──► YarnDialogueRunner
                                                                        │ run_line / run_options
                                                                        ▼
                         DialogueHooks ◄── game functions ──   ChatPresenter ──► ChatView (phone screen)
```

- **`dialogue/`:** the writers' files (see `docs/WRITING_GUIDE.md`).
- **`dialogue/dialogue_hooks.gd`:** everything a conversation can ask the game (`ran_stop_sign()`) or
  tell it (`<<start_thread>>`). It must stay in this folder; its header explains why.
- **`game/phone/conversation/chat_presenter.gd`:** the bridge. Yarn calls `run_line` for each line
  and `run_options` for each set of choices, and waits for them to return. Waiting for a delay,
  typing or a click is what paces a conversation.
- **`game/phone/conversation/chat_view.gd`:** the phone screen. It knows nothing about Yarn: bubbles,
  typing indicator, choice buttons, reply countdown, typing box.
- **`game/phone/conversation/typing_rule.gd`:** what counts as typing the message correctly (exact
  match for now).
- **`game/debug/dialogue_playtest/`:** the writers' playtest scene, built from the same pieces plus
  editors for variables and fake game state.

The in-car phone (`game/phone/phone.gd`) still runs the 2024 typing prototype. Roadmap B2 swaps it
for `ChatView` + `ChatPresenter`.

## Tools and tests (`tools/`)

| File | What it does |
|---|---|
| `validate_dialogue.gd` + `dialogue_validator.gd` | Checks dialogue against the writing guide (runs the Yarn compiler, then our own rules) |
| `check_scenes.gd` | Runs every scene for a few frames; fails on any error |
| `tests/test_dialogue_validator.gd` | The validator against fixture files with `// expect:` markers |
| `tests/test_dialogue_playtest.gd` | Plays the sample conversation end to end |
| `tests/test_car.gd` | Driving targets, identical results at any frame rate, camera, phone placements |
| `tests/test_course.gd` | Checkpoints, finish, timer, and a drive through the stop sign |
| `ci/run_godot.sh` | CI wrapper: fails on printed script errors and hangs, not just the exit code |
| `setup_yarn_spinner.*` | Installs the (uncommitted) Yarn Spinner addon at a pinned version |

CI (`.github/workflows/`) runs all of these on pull requests. The commands are in the README's
"Checks" section.

## Suggested reading order

1. `game/car/BaseCar.gd`: short, and the core of the driving.
2. `game/car/Camera3D.gd`, then `game/car/phone_mount.gd`: the phone glance.
3. `game/phone/conversation/chat_presenter.gd`, then `chat_view.gd`: how a conversation plays.
4. `dialogue/dialogue_hooks.gd`: the contract between writers and code.
5. `game/rules/course.gd`.
6. Tools when you want them. `tools/dialogue_validator.gd` is the longest file; its `_check_file`
   comment explains the approach.

Older 2024 code (`phone.gd`, `stopSign.gd`, `follow_camera/`) has `NOTE:` comments where it
behaves in ways you might not expect.
