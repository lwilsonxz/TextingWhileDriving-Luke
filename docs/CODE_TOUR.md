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
│   └── Phone         phone.tscn: a ChatView drawn onto a quad; passes keys and clicks to it
└── Hud               speed and "TRAFFIC VIOLATION!" labels
```

- **`game/car/BaseCar.gd`:** read `_physics_process` top to bottom. Every tuning value is an
  `@export` at the top, with a comment on what it does; the defaults give realistic car numbers.
  The car also keeps its driving record for the level (`violations`, `ran_last_stop_sign`), which
  conversations read.
- **`game/car/Camera3D.gd` (`CarCamera`):** views are position + rotation (+ zoom) pairs the camera
  glides between. `is_looking_at_phone()` and `view_changed` are what later distraction mechanics
  will use.
- **`game/car/phone_mount.gd`:** the five phone placements (F7 cycles them).
- **`game/phone/phone.gd`:** the phone in the car. Its screen is a `ChatView` in a SubViewport, shown as
  the texture of a quad. A SubViewport on a quad gets no input by itself, so `_input` passes keys on
  as they are and traces mouse clicks from the camera onto the quad (`screen_point()`). By default it
  only does this while the camera looks at the phone.
- **`game/settings.gd`:** playtest options saved between sessions (F6/F7/F8), autoloaded as `Settings`.
- **`game/global.gd`:** the `is_driving` flag (F5 debug toggle), and Escape to quit.

## Levels

- **`game/levels/test_course.tscn`:** the main scene. Roads are a GridMap painted from the road kit in
  `game/world/models/roads-v4.tres`.
- **`game/rules/course.gd`:** checkpoints in order, finish line, timer. Its signals are where level
  flow (B4) will hook in.
- **`game/rules/text_trigger.gd` (`TextTrigger`):** starts a conversation on the phone when the car
  drives in, or a set time after the level starts. The test course's `MomTexts` is one.
- **`game/rules/stopSign.gd`:** the 2024 stop sign rule. It records running the sign on the car
  (`record_violation`). Its header comment lists known limits; roadmap B3 generalises it.
- **`game/levels/main.tscn`:** the old ramps sandbox.

## Conversations (the dialogue pipeline)

```
TextTrigger (in a level) ──┐
<<start_thread>> ──────────┴──► PhoneService ──► YarnDialogueRunner ◄── writers' .yarn files
                                                       │                 (compiled on import)
                                     run_line / run_options     game functions
                                                       ▼                 ▼
                     ChatView (phone screen) ◄── ChatPresenter     DialogueHooks ──► the player's car
                                                                                   (driving record)
```

In the game, `PhoneService` owns the runners and presenters and the car's phone supplies the
`ChatView`. In the playtest scene, the scene builds its own runner and presenter instead.

- **`dialogue/`:** the writers' files (see `docs/WRITING_GUIDE.md`).
- **`dialogue/dialogue_hooks.gd`:** everything a conversation can ask the game (`ran_stop_sign()`) or
  tell it (`<<start_thread>>`). Functions read the player's car; commands go to `PhoneService`. It
  must stay in this folder; its header explains why.
- **`game/phone/phone_service.gd` (autoload `PhoneService`):** plays conversations on the car's phone.
  `start_thread("Mom", "Mom_L1_Start")` plays one, or queues it while another is playing (one
  conversation on screen at a time for now). It holds the story variables, so they carry over between
  levels, and one Yarn runner per project, loaded at level start by `prepare()`.
- **`game/phone/conversation/chat_presenter.gd`:** the bridge. Yarn calls `run_line` for each line
  and `run_options` for each set of choices, and waits for them to return. Waiting for a delay,
  typing or a click is what paces a conversation.
- **`game/phone/conversation/chat_view.gd`:** the phone screen. It knows nothing about Yarn: bubbles,
  typing indicator, choice buttons, reply countdown, typing box.
- **`game/phone/conversation/typing_rule.gd`:** what counts as typing the message correctly (exact
  match for now).
- **`game/debug/dialogue_playtest/`:** the writers' playtest scene, built from the same pieces plus
  editors for variables and fake game state.


## Tools and tests (`tools/`)

| File | What it does |
|---|---|
| `validate_dialogue.gd` + `dialogue_validator.gd` | Checks dialogue against the writing guide (runs the Yarn compiler, then our own rules) |
| `check_scenes.gd` | Runs every scene for a few frames; fails on any error |
| `tests/test_dialogue_validator.gd` | The validator against fixture files with `// expect:` markers |
| `tests/test_dialogue_playtest.gd` | Plays the sample conversation end to end |
| `tests/test_car.gd` | Driving targets, identical results at any frame rate, camera, phone placements |
| `tests/test_course.gd` | Checkpoints, finish, timer, and a drive through the stop sign |
| `tests/test_phone.gd` | The phone in the car: a trigger starts Mom's conversation; click a choice on the 3D phone and type the reply; the stop-sign branch; the queue |
| `ci/run_godot.sh` | CI wrapper: fails on printed script errors and hangs, not just the exit code |
| `setup_yarn_spinner.*` | Installs the (uncommitted) Yarn Spinner addon at a pinned version |

CI (`.github/workflows/`) runs all of these on pull requests. The commands are in the README's
"Checks" section.

## Suggested reading order

1. `game/car/BaseCar.gd`: short, and the core of the driving.
2. `game/car/Camera3D.gd`, then `game/car/phone_mount.gd`: the phone glance.
3. `game/phone/conversation/chat_presenter.gd`, then `chat_view.gd`: how a conversation plays.
4. `game/phone/phone_service.gd`, then `game/phone/phone.gd`: how a conversation gets onto the phone
   in the car, and how keys and clicks reach it.
5. `dialogue/dialogue_hooks.gd`: the contract between writers and code.
6. `game/rules/text_trigger.gd` and `game/rules/course.gd`: what a level hooks into.
7. Tools when you want them. `tools/dialogue_validator.gd` is the longest file; its `_check_file`
   comment explains the approach.

Older 2024 code (`stopSign.gd`, `follow_camera/`) has `NOTE:` comments where it
behaves in ways you might not expect.
