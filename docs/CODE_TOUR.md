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
└── Hud               the speedometer
```

- **`game/car/BaseCar.gd`:** read `_physics_process` top to bottom. Every tuning value is an
  `@export` at the top, with a comment on what it does; the defaults give realistic car numbers.
  At the bottom, `_detect_crash` emits `crashed` when the car loses a lot of speed in a moment.
- **`game/car/Camera3D.gd` (`CarCamera`):** views are position + rotation (+ zoom) pairs the camera
  glides between. `is_looking_at_phone()` and `view_changed` let other systems react to
  where the driver looks (looking away never takes control away).
- **`game/car/phone_mount.gd`:** the five phone placements (F7 cycles them).
- **`game/phone/phone.gd`:** the phone in the car. Its screen is a `ChatView` in a SubViewport, shown as
  the texture of a quad. A SubViewport on a quad gets no input by itself, so `_input` passes keys on
  as they are and traces mouse clicks from the camera onto the quad (`screen_point()`). By default it
  only does this while the camera looks at the phone.
- **`game/settings.gd`:** playtest options saved between sessions (F6/F7/F8), autoloaded as `Settings`.
- **`game/global.gd`:** the `is_driving` flag (F5 debug toggle), and Escape to quit.

## Levels

How to build one (for designers): `docs/LEVEL_GUIDE.md`.

- **`game/levels/test_course.tscn`:** the first level. Roads are a GridMap painted from the road kit in
  `game/world/models/roads-v4.tres`; everything else is drag-in pieces.
- **`game/levels/level_template.tscn`:** the starting point for new levels. Designers duplicate it.
- **`game/world/pieces/`:** the drag-in level pieces. Each `.tscn` is a node with its script and
  collision shape, ready to drop into a level:
  - `spawn.tscn` (`spawn_point.gd`, `SpawnPoint`): moves the level's car here when the level starts.
  - `checkpoint.tscn` (`Checkpoint`, with a `number`) and `finish.tscn` (`FinishLine`): they join
    groups, and the `Course` finds them.
  - `stop_sign.tscn`, `speed_zone.tscn`, `text_trigger.tscn`: the rules and trigger from
    `game/rules/` with their shapes (and the stop sign model).
  - **`piece_marker.gd` (`PieceMarker`):** draws each piece in the editor only (a coloured box, an
    arrow, a label). The piece scripts are `@tool` so this runs in the editor. Each one starts with
    `if Engine.is_editor_hint(): ... return`, so nothing else runs there.
- **`game/rules/course.gd`:** finds the level's checkpoints (sorted by number) and finish line by
  group, wherever they are in the level; it handles order and the timer. Its signals are where level
  flow (B4) will hook in.
- **`game/rules/text_trigger.gd` (`TextTrigger`):** starts a conversation on the phone when the car
  drives in, or a set time after the level starts. The test course's `MomTexts` is one.
- **`game/levels/main.tscn`:** the old ramps sandbox.

Anything visual made in code is marked `ART PLACEHOLDER` and listed in `docs/ART_PLACEHOLDERS.md`.

## Level flow: title, results, next level, saving

```
title screen ──New game / Continue──► GameFlow ──loads──► level (from level_order.tres)
                                         ▲                    │ LevelState: level_started(),
                                         │                    │ then the Course's finish line
                                         └── level_completed(summary) ◄─┘
                                                │
                                   results screen: Next level (Enter) / Retry (R)
```

- **`game/flow/game_flow.gd` (autoload `GameFlow`):** new game, continue, next level, retry, back to
  the title. After each level of a run it saves which level is next and every story variable
  (`user://save.cfg`). A retry puts the story variables back to how they were when the level started.
  Only runs started from the title screen save, so playing a level with F6, or a test, never
  touches saved progress.
- **`game/flow/level_order.gd` (`LevelOrder`) and `game/levels/level_order.tres`:** the list of
  levels in play order, edited in the Inspector.
- **`game/ui/title_screen.tscn`** (the main scene) and **`game/ui/results_screen.gd`**: both are
  code-made placeholders (see `docs/ART_PLACEHOLDERS.md`).
- **`LevelState`** is the link: it tells `GameFlow` when the level starts, listens to the level's
  `Course` (found by group) for the finish, and sends the summary (time, violations, crashes, and
  `PhoneService`'s counts of messages sent and replies missed).

## Traffic rules and the level's record

```
StopSign / SpeedZone / OffRoadRule  (each a TrafficRule)
        │ broken("Ran a stop sign") / obeyed()
        ▼
   LevelState  ◄── crashed(impact_kmh) ── the car (BaseCar)
        │ shows warnings and the "level failed" screen; R restarts
        ├──► dialogue functions: violations(), crashes(), ran_stop_sign()
        └──◄ dialogue commands: <<fail_level "...">>, <<level_event name>>
```

- **`game/rules/level_state.gd` (`LevelState`):** one per level. It records violations and crashes,
  and fails the level after `max_violations`, on a crash (`fail_on_crash`), or when a conversation
  says so. Rules and the dialogue find it through its group; `LevelState.find(node)` returns it.
- **`game/rules/traffic_rule.gd` (`TrafficRule`):** the base for rules. A rule is a zone (Area3D) that
  knows when the player's car is inside (`car`, `car_entered`, `car_exited`) and reports
  `broken(...)` or `obeyed()`. Read this first; each rule is short.
- **`stop_sign.gd`** (must slow below 18 km/h in the zone), **`speed_zone.gd`** (one violation per
  visit over the limit), **`off_road.gd`** (more than a second off the road tiles of a GridMap; it
  needs no zone).

## Conversations (the dialogue pipeline)

```
TextTrigger (in a level) ──┐
<<start_thread>> ──────────┴──► PhoneService ──► YarnDialogueRunner ◄── writers' .yarn files
                                                       │                 (compiled on import)
                                     run_line / run_options     game functions
                                                       ▼                 ▼
                     ChatView (phone screen) ◄── ChatPresenter     DialogueHooks ──► LevelState
                                                                                   (driving record)
```

In the game, `PhoneService` owns the runners and presenters and the car's phone supplies the
`ChatView`. In the playtest scene, the scene builds its own runner and presenter instead.

- **`dialogue/`:** the writers' files (see `docs/WRITING_GUIDE.md`).
- **`dialogue/dialogue_hooks.gd`:** everything a conversation can ask the game (`ran_stop_sign()`) or
  tell it (`<<start_thread>>`). Functions read the level's `LevelState`; commands go to `PhoneService` or the `LevelState`. It
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
| `tests/test_rules.gd` | Each traffic rule, crashes, failing a level and restarting, and the dialogue hooks that read them |
| `tests/test_level_flow.gd` | Title, New game, results, retry (story variables restored), next level, fail and retry, back to the title, saving and Continue |
| `tests/test_level_pieces.gd` | The level template: the car starts at the Spawn, checkpoints are sorted by number, the template drives start to finish, and pieces draw nothing in the game |
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
6. `game/rules/traffic_rule.gd`, one rule (`stop_sign.gd`), then `level_state.gd`: how driving
   badly is counted.
7. `game/world/pieces/` (start with `checkpoint.gd` and `piece_marker.gd`), then
   `game/rules/course.gd`: how a level is put together.
8. `game/flow/game_flow.gd`: how levels follow each other and progress is saved.
9. Tools when you want them. `tools/dialogue_validator.gd` is the longest file; its `_check_file`
   comment explains the approach.

Older 2024 code (`follow_camera/`) has `NOTE:` comments where it behaves in ways you might not
expect.
