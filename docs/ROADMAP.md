# Texting While Driving: Prototype & Dialogue Tooling Roadmap

> Status: **reviewed draft**. Decisions so far are listed in [Decisions](#decisions) at the end.
> In short: GDScript only, Godot 4.6.x, Yarn Spinner for writing, Windows only, a gamepad drives
> while mouse and keyboard work the phone, typing must be exact at first, and replies arrive on timers.

This document has five parts:

1. [What's in the repo today, and what's worth keeping](#1-repo-audit)
2. [The dialogue tool recommendation](#2-dialogue-tool-recommendation)
3. [Roadmap A: dialogue creation pipeline (start now, unblocks writers)](#3-roadmap-a-dialogue-creation-pipeline)
4. [Roadmap B: minimum playable prototype](#4-roadmap-b-minimum-playable-prototype)
5. [Roadmap C: level builder](#5-roadmap-c-level-builder)

Decisions made so far, and the questions still open, are collected at the end.

---

## 1. Repo audit

The repo is a Godot **4.2** jam-style project (~10 small scripts). The car is based on the MIT-licensed
"Car-Demo" by Manik Sharma (`TextingWhileDriving/LICENCE.txt`; keep that notice if we keep the car code).
The design doc that used to live in `README.md` (see git history) is mostly empty headings. The
useful line from it is: *"Progressing through linear stages with branching story/dialogue... fail conditions
for failure to obey traffic laws, as well as texting challenges."*

| File / system | What it does | Verdict |
|---|---|---|
| `cars/BaseCar.gd`, `BaseCar.tscn`, `Doge.tscn` | `VehicleBody3D` car with 4 wheels, steering, handbrake, low-speed torque boost, HUD speed label | **Keep as a starting point.** It works and is the "physics-y" base. Clean up: it reads raw `KEY_UP/DOWN` instead of the input map, the speed math is odd (`* FPS * delta`, `* 3.8` for km/h), and the `Hud` lives inside the car scene. |
| `cars/Camera3D.gd` | Lerped camera presets: front, rear, left window, **phone view** | **Keep the idea, rewrite.** "Glance down at the phone" vs "look at the road" is a core mechanic. The code itself says it should store position/rotation *pairs*; do that. |
| `cars/camera/CameraFollow.gd` | Third-person follow cam | Optional. It's useful for a "streamer" chase cam or a replay. |
| `phone.gd` / `phone.tscn` | 2D UI rendered into a `SubViewport` and mapped onto a 3D quad in the car | **Keep the technique**, since it's the right way to put a usable phone inside the 3D cabin. **Throw away the logic:** it's a hard-coded "type SOME DUMB BULLSHIT to win" check. |
| Typing input (`phone.gd::_unhandled_input`) | Appends `OS.get_keycode_string()` per key | **Throw away.** It produces `"A"` instead of `"a"`, `"Comma"` instead of `","`, `"Shift"` on shift, etc. Replace it with `InputEventKey.unicode`-based input. |
| `text_node.gd/.tscn` | A read-only `LineEdit` used as a label | Throw away (replace with real message bubbles). |
| `stopSign.gd` | `Area3D` that projects car velocity onto the sign's normal and flags "TRAFFIC VIOLATION" if you never slowed down | **Keep the idea.** Generalise it into a `TrafficRule` base with stop signs, red lights, speeding, etc. It has a small bug: `get_body_projected_speed(body)` ignores its argument. |
| `main.tscn` | Test level: CSG ramps/bumps, `GridMap` road tiles, one stop sign, the car | Keep as a sandbox/test track. Note that it instances `phone.tscn` **twice** (once under `doge-body`, once under `car`), so both phones receive keystrokes. |
| `Models/roads-v4.*` (GridMap MeshLibrary), stop sign GLBs, Doge car model | Assets | Keep. GridMap roads are a good fit for quickly blocking out courses. |
| `global.gd` | Autoload with a single `is_driving` bool toggled by key `5` | Replace with a real game-state autoload. |
| `victory_screen.tscn` | "YOU WIN" label | Placeholder. |

**Repo hygiene** (✅ done in B0, except Git LFS):
- 169 files under `TextingWhileDriving/.godot/` are committed even though `.gitignore` lists them.
  Run `git rm -r --cached TextingWhileDriving/.godot`.
- Six editor `*.tmp` files are committed (`cars/Dog*.tmp`, `pho917E.tmp`, `camBA0D.tmp`). Delete them and ignore `*.tmp`.
- Replace the inherited Car-Demo `README.md` with a real one.
- Consider Git LFS for `*.glb/*.png/*.jpg` before the art grows. The `.git` folder is already 65 MB.

**Bottom line:** nothing here constrains the design. Keep the car physics, the phone-on-a-quad technique,
the camera-glance concept, the stop-sign detection idea and the road assets. Rewrite everything else.
Nothing dialogue-related exists yet.

---

## 2. Dialogue tool recommendation

### What writers in the industry actually use

| Tool | Style | Used on | Godot + GDScript support | Fit for us |
|---|---|---|---|---|
| **Yarn Spinner** | Screenplay-like script, **with a live node-graph view in VS Code** (drag, colour-code, sticky notes) | Night in the Woods, A Short Hike, DREDGE | Official GDScript port: **alpha → beta in 2026**, pure GDScript, needs **Godot 4.6+**. The C# version is stable. | **Recommended** |
| **Ink** (inkle) | Script, Inky editor with live preview (no graph) | 80 Days, Heaven's Vault, Sorcery! | `inkgd` (GDScript): runtime is feature-complete but has no official Godot 4 release (use the `godot4` branch) and is slower than C# | Strong runner-up |
| **articy:draft X** | Full drag-and-drop node graph, database of characters/variables | Disco Elysium and many AAA studios | No official Godot importer, only community JSON importers | Most "pro", but heavy, Windows-focused, and needs a custom importer |
| **Dialogue Manager** (Nathan Hoad) | Script edited *inside* the Godot editor | Many Godot indies | Native GDScript, mature (v3.x/4.x) | Great runtime, but no graph view and writers must work inside Godot |
| **Twine** | Drag-and-drop passages in the browser | Prototyping, IF | Needs a custom exporter | Good for sketching, weak for production |

### Why Yarn Spinner

1. **It matches the writer workflow you chose.** Writers type fast in plain text, VS Code shows the
   branching graph, and files diff and merge cleanly in git (graph tools' binary/huge-JSON saves don't).
2. **There's no export step to maintain.** The Godot plugin imports `.yarn` files directly as resources,
   so "scripts that turn the save data into Godot objects" largely come for free. Our scripts become
   *validation* and a *playtest scene* rather than a converter.
3. **The features we need are built in:** variables, conditions on options, `<<jump>>`, custom
   `<<commands>>` and functions that call into game code, per-line `#hashtags` metadata, line IDs for
   localisation, and custom "Dialogue Presenters" that let us render lines as phone message bubbles.
4. **Writers can start before the game exists.** The VS Code extension has its own preview, and the
   format won't change once the runtime is hooked up.

**Main risk:** the GDScript runtime is pre-1.0. We handle it two ways:
- A 1–2 day **spike** (step A0 below) checks every feature we rely on before writers invest heavily.
- All game code talks to *our own* thin `PhoneThread` wrapper, never to Yarn directly. If the
  runtime disappoints, the fallback is a small importer for the subset of Yarn syntax we use
  (`.yarn` → JSON → Godot `Resource`, roughly 1–2 weeks). The writers' files don't change either way.

---

## 3. Roadmap A: dialogue creation pipeline

**Goal:** writers produce branching text-message conversations in a UI, and those load into Godot
as playable phone threads. This track depends on nothing in Roadmap B except the repo cleanup and
the 4.6 upgrade.

### A0. Spike: prove the runtime ✅ done: **GO**
Full results: [`docs/spikes/A0-yarn-spinner.md`](spikes/A0-yarn-spinner.md). Tested on Godot 4.6.3 with
Yarn Spinner for Godot (GDScript) Early Access 3.2:
- [x] A `.yarnproject` imports, and edits to `.yarn` files re-import
- [x] A custom Dialogue Presenter receives lines, options and **hashtags** (`#delay:1.5`)
- [x] Custom commands (`<<typing 0.2>>`) and functions (`<<if ran_stop_sign()>>`) call GDScript
  (they must be `static` methods to be global)
- [x] Variables can be read/written from game code and saved/loaded to disk
- [x] Options with conditions, and "hidden" options we can auto-select on a timeout
- [x] **Two dialogue runners at once**, sharing one variable store
- [x] It runs headless (`godot --headless`) so CI can validate files

The addon isn't committed (licence). Install it with `tools/setup_yarn_spinner.sh` / `.ps1`.
Compiling needs the `ysc` tool (.NET); see the results doc for setup.

### A1. "Texting screenplay" conventions ✅ done
The format is in [`docs/WRITING_GUIDE.md`](WRITING_GUIDE.md), with a copy-ready
[`template.yarn`](writing/template.yarn) and [`Variables.yarn`](writing/Variables.yarn) (both compile
cleanly). Summary:
- `Name: text` = incoming message, `Me: text` = what the player must type, `System: text` = phone notice
- `-> Short label` = a choice; the `Me:` lines under it are the typed text. Every choice needs one,
  except a hidden `#timeout:N` choice, which is auto-picked when the player doesn't answer.
- `#delay:N` = gap before an incoming message, shown as the typing indicator; `<<wait N>>` = silence
- Node titles `<Thread>_<Level>_<Beat>`; one file per thread per level; all variables declared in
  `dialogue/Variables.yarn`
- Characters that must be escaped in lines (`\#`, `\[ \]`, `\{ \}`, `\/\/`, `\\`) were checked against the
  real compiler and runtime, along with an easy/harder/hardest character tiering for typed text.

Changes from the first sketch of this format: the game, not the file, decides which thread a
conversation runs in (so no `<<thread>>` command), and the typing indicator is automatic during
`#delay` (so no `<<typing>>` command).

### A2. Writer setup (½ day)
- Install VS Code + the **Yarn Spinner** extension and clone the fork (writers are comfortable with git).
- Writers who will also run the playtest scene: Godot 4.6.x, then `tools\setup_yarn_spinner.ps1`, and the
  `ysc` compiler (see the [A0 results](spikes/A0-yarn-spinner.md)).
- Folder layout: `TextingWhileDriving/dialogue/<level>/<contact>.yarn` plus one `.yarnproject`.
- Branch naming: descriptive names (e.g. `dialogue-mom-level1`), merged to `main` by PR.
- **Writers can start writing at the end of A1/A2**, using the VS Code graph + preview, before any
  game code exists.

### A3. Validation script + CI ✅ done
`godot --headless --script tools/validate_dialogue.gd` (logic in `tools/dialogue_validator.gd`), run on
every PR and push to `main` that touches dialogue by `.github/workflows/dialogue.yml`. Problems show
inline on the PR.
- **Compiler:** runs `ysc` with a definitions file generated from `dialogue_hooks.gd`. Warnings
  (missing jump targets, undeclared variables) count as errors.
- **Checks Yarn can't do:** unknown commands and functions (ysc silently accepts unknown functions),
  `<<start_thread>>` targets that don't exist
- **Writing-guide rules:** every message has a sender, no quoted names, every visible choice has a
  `Me:` line, 1–4 visible choices, at most one `#timeout` per set, only `#delay`/`#timeout`/`#line`
  tags with valid values, unescaped `[ ]` and `://`, node titles match file and level folder,
  `<<declare>>` only in `Variables.yarn`, files live in level folders, names spelled two ways
  ("John Doe" / "john doe")
- **Report:** per-file nodes, choices, incoming/typed word counts, typed characters, typed lines by
  difficulty tier, and the list of entry points (nodes the game must start)
- **Tests:** `tools/tests/test_dialogue_validator.gd` checks the writing-guide template passes and
  every marked problem in `tools/tests/fixtures/invalid/` is reported, and nothing else

### A4. Dialogue Playtest scene ✅ done
`game/debug/dialogue_playtest/dialogue_playtest.tscn` (F6), described for writers in
[WRITING_GUIDE §11](WRITING_GUIDE.md#11-playtesting-on-the-phone):
- Pick a Yarn project and node (entry points marked) and play it on the phone UI
- Typing challenge with typo feedback, or **Skip typing**; real `#delay`s, or **Skip delays**
- Writer mode shows hidden `#timeout` choices and false-condition choices, greyed out with notes
- Editable story variables, faked game functions (`ran_stop_sign()`, `violations()`), a command log
- **Back** (previous node with its variables) and **Restart**

Built along the way, and reused by B2 and A5:
- `game/phone/conversation/ChatView`: the phone conversation control (bubbles, typing indicator,
  choices, reply countdown, typing challenge). It's a 2D control, so B2 can put it on the in-car
  phone's SubViewport.
- `ChatPresenter`: the Yarn presenter implementing the writing guide (`Me:`/`System:`, `#delay` with
  a 1–3 s default, hidden `#timeout` auto-pick).
- `TypingRule`: exact match for now. Typo-tolerance experiments go here.
- `DialogueHooks.fakes` / `command_listener`, so tools can stand in for the game.

Tests: `tools/tests/test_dialogue_playtest.gd` plays the sample end to end (choices, typing with a
typo, Back, faked hooks, timeouts, delays, player vs writer mode) and runs in CI.

Fixed along the way:
- **Hooks moved to `dialogue/dialogue_hooks.gd`.** The Yarn plugin only writes game hooks into
  `Dialogue.ysls.json` (writers' VS Code autocomplete) for scripts inside the Yarn project's folder.
  After B0 moved the hooks to `game/phone/`, any regeneration would have silently emptied it. A
  validator test now fails if that file is missing any hook.
- **CI runs Godot through `tools/ci/run_godot.sh`**, which also fails on any printed GDScript error
  and times out hung runs. A runtime error inside game code doesn't change Godot's exit code, and a
  script that errors before `quit()` hangs.

### A5. Runtime integration layer (3–5 days, overlaps with B2)
> **Started in B2:** `PhoneService` (start/queue threads, shared story variables, `prepare()` at level
> start) and the game hooks now read the real car. Per-contact `PhoneThread`s and save/load remain.

- `PhoneService` autoload: owns all threads, the shared story variables, and save/load
- `PhoneThread`: one per contact. It wraps a dialogue runner, stores message history, and emits
  `message_received`, `options_presented`, `typing_required`, `thread_finished`
- The MVP UI shows only the active thread. Because each contact already has its own runner and
  history, adding a thread list with notifications later is UI work, not a redesign.
- Gameplay hooks: writer-facing commands and functions are `static func _yarn_command_*` /
  `_yarn_function_*` methods on one `class_name` hooks script, so they're global and appear in
  `.ysls.json` (compiler types + VS Code autocomplete). Levels start threads with
  `PhoneService.start_thread("Mom", "Mom_Level1_Intro")`.
- Create all of a level's runners at level start, never mid-drive (loading stalls a frame and skews
  the next few timers)
- Save/load every story variable through a typed or custom `YarnVariableStorage`, not a hand-kept list

### A6. Later (post-prototype)
- Localisation via Yarn line IDs (`#line:` tags generated by tooling)
- Branch coverage: log which nodes playtesters actually reach
- Read receipts, "seen at", reactions, photos/stickers as tag-driven features
- Re-evaluate Yarn GDScript once it hits 1.0

**Timeline:** writers are unblocked in about **one week** (A0–A2). A full writer loop (write → validate → play
on the phone) takes about **2–3 weeks** of one programmer's focused time.

---

## 4. Roadmap B: minimum playable prototype

**Prototype definition ("done" means):** one 3–5 minute drive on one course, with one or two
conversations of 2–3 branches each, where **driving and texting pressure each other**. It has a fail state,
a win state, and at least one story variable that carries into a second short drive and changes what's said.

### B0. Foundation ✅ done
- **Repo hygiene:** the `.godot` cache and editor `*.tmp` files are no longer committed. `main.tscn`
  pointed straight into the import cache for one texture; it now points at the source image, so a fresh
  clone works. The Car-Demo README was replaced and its licence moved next to the car code.
  (Git LFS not adopted yet.)
- **Godot 4.6.3:** the project is upgraded (new `.uid` files for scripts, refreshed `.import`
  settings), and the Yarn Spinner plugin is enabled, installed by `tools/setup_yarn_spinner.*`. The plugin
  generates `dialogue/Dialogue.ysls.json` from the game hooks, for VS Code autocomplete.
- **Layout:** `TextingWhileDriving/game/{car,levels,phone,rules,ui,world}` plus `dialogue/`; see the
  root README. Unused Car-Demo screenshots were removed.
- **Input map** (hybrid scheme):

  | Action | Gamepad | Keyboard |
  |---|---|---|
  | `drive_accelerate` / `drive_reverse` | RT / LT | ↑ / ↓ |
  | `drive_steer_left` / `drive_steer_right` | left stick | ← / → |
  | `drive_handbrake` | B | Right Ctrl |
  | `camera_front_view` / `_rear_view` / `_left_window_view` | D-pad ↑ / ↓ / ← | F3 / F1 / F2 |
  | `camera_phone_view` | LB | F4 |
  | `phone_send` / `phone_delete` | | Enter / Backspace |
  | `debug_toggle_driving` | | F5 |

  Camera and debug keys moved off `1`–`5`, and the handbrake off Space, because those are needed for
  typing. `BaseCar.gd` now uses actions instead of raw keys. A headless drive test showed the same
  behaviour as before (↑ drives forward, ↓ brakes/reverses). The old typing code in `phone.gd` still
  reads raw keys; B2 replaces it.
- **Scene smoke check:** `tools/check_scenes.gd` loads and runs every scene and fails on any error.
  CI (`.github/workflows/project.yml`) runs it on every PR that touches the game.

### B1. Driving core ✅ done
- **Car controller rewritten (`game/car/BaseCar.gd`)**, with bugs fixed:
  - **Frame rate:** acceleration depended on frame rate (speed was multiplied by the rendering FPS).
    The same 2 s press ended at 92–136 km/h depending on FPS; now it's identical at any frame rate.
  - **Braking:** "am I rolling backwards?" was tested with a direction cosine, so accelerate never
    braked while reversing.
  - **Force curve:** the launch boost had a jump in engine force at 30 m/s.
  - **Debug toggle:** toggling driving off mid-press left the throttle stuck on.
- **New behaviour:**
  - **Analog triggers:** half trigger means half power.
  - **Brake, then reverse:** pressing the opposite direction brakes, then reverses.
  - **Realistic speeds:** 0–100 km/h in ~9 s (was 1.4 s), top speed ~140 km/h, 100–0 km/h in
    3.3 s over 43 m, reverse capped at 25 km/h (before, reverse had no limit and reached ~190 km/h).
  - **HUD:** shows real km/h.
- **Tuning:** every value is an export with a description. The car's tuning now lives in `Doge.tscn`
  (it was overrides inside one level), as do its phone and the "TRAFFIC VIOLATION" label, so any level
  that drops in the car gets the same car.
- **Camera (`CarCamera`):** named views (road, rear, left window, phone) that glide at any frame rate.
  The phone button works as **toggle** or **hold** (`phone_glance` export, both ready to playtest).
  `is_looking_at_phone()` and `view_changed` let other systems react to where the driver looks.
- **Fixed:** the level instanced the phone twice. A render confirmed which copy was the visible one.
- **Test course (`game/levels/test_course.tscn`, now the main scene):** a ~530 m loop from the road
  kit, with a stop sign, 3 ordered checkpoints, a finish line just behind the start, and a timer/HUD
  (`Course` emits `checkpoint_reached`, `finish_blocked`, `finished` for B4). `main.tscn` stays as
  the ramps sandbox.
- **Tests (in CI):**
  - `test_car.gd` drives on flat ground at several frame-rate caps and requires identical results;
    it also covers brakes, reverse, top speeds, steering, analog throttle, handbrake and both camera
    modes.
  - `test_course.gd` checks the checkpoint order and finish rules and drives through the stop sign.

**Playtest options** (`Settings` autoload, saved between sessions):
- **F6** switches the phone glance between **toggle** and **hold**.
- **F7** cycles the phone between five **placements**: dash mount, vent mount, centre console, lap
  and windshield. They trade how far the eyes leave the road against how much road the phone hides.
  The phone is now real size (it was 0.38 × 0.8 m), faces the driver, and the glance aims and zooms
  at it, so a new placement is one line in `PhoneMount.PLACEMENTS`.
- A short note on screen confirms each change. Tests check that every placement's glance centres
  the phone, and that the keys and saving work.
- The car's tuning values are all exports on `BaseCar.gd`, with a comment on what they produce.

### B2. Phone core: conversations play in the car ✅ mostly done
- **The in-car phone runs real conversations.** `ChatView` (A4) is on the phone's screen, replacing
  the 2024 typing test. It's drawn at 2× for sharp text and unshaded so it's readable in any light.
- **Input from the 3D phone:** keys go to the screen for typing, and mouse clicks are traced onto the
  quad, so choices can be clicked on the phone in the car. By default this only works while looking
  at the phone. **F8** switches that (a new playtest option): "typing needs a glance" vs "type without
  looking".
- **Typing challenge:** exact match with live red typos, as in the playtest scene (`TypingRule` keeps
  the comparison swappable for typo-tolerance experiments).
- **`PhoneService` autoload (the first part of A5):**
  - `start_thread(thread, node)` plays a conversation, or queues it while another plays.
  - The story variables are shared by every conversation and kept between levels.
  - `prepare()` loads Yarn at level start, not mid-drive.
- **`TextTrigger` (`game/rules/text_trigger.gd`):** starts a conversation when the car drives in, or N
  seconds after the level starts. The test course has one just after the stop sign. It plays the
  writing template's sample conversation until a real one exists in `dialogue/`.
- **The driving reaches the dialogue:**
  - The car records its violations, so `ran_stop_sign()` and `violations()` read the real drive.
  - `<<start_thread>>` queues the next conversation on the phone.
  - The writing guide's §8 now marks all three as available.
- **Tests:** `test_phone.gd` (in CI) covers the whole path on the test course:
  - drive through the trigger, then click a choice through the 3D phone and type the reply with a
    typo and a fix;
  - the "ran the stop sign" branch, after the reply deadline passes;
  - the F8 option, the queue, and the level ending mid-conversation.
- **Still to do:**
  - Pick a default phone placement, glance mode and F8 option after playtesting (B1's F6/F7 plus F8).
  - Readability: at the default 1152×648 window the phone's text is small. `PhoneMount.SCREEN_FILL`
    (how much of the view the phone fills) is the knob to playtest.
  - Gamepad-only replies (choices on the D-pad) if playtests want them; the hybrid controls decision
    says mouse and keyboard work the phone.
  - **Not yet done from A5:** a `PhoneThread` per contact with its own history (several threads live
    at once), and saving story variables to disk.

### B3. The coupling: what makes it a game ✅ done (red lights wait for a model)
**No artificial distraction.** The original plan reduced the road view and dampened steering while
looking at the phone. That's dropped (see the "Texting and driving" decision): the player has full
control of both at all times, and the danger comes from where they choose to look.

**Done:**
- **`LevelState` (one per level):** records traffic violations and crashes, shows warnings
  ("TRAFFIC VIOLATION: Ran a stop sign", "CRASH!"), and fails the level:
  - after `max_violations`;
  - on a crash (`fail_on_crash`);
  - or when a conversation says so (`<<fail_level "reason">>`).
  The failed screen offers R / Start to try again. It replaces the car's old "TRAFFIC VIOLATION!" label.
- **`TrafficRule` base:** a zone that knows when the player's car is inside and reports `broken()` or
  `obeyed()`. Rules built on it:
  - **`StopSign`:** replaces `stopSign.gd` and fixes its limits (per-frame printing, wiring signals by
    hand, the direction TODO). It ignores traffic going the other way.
  - **`SpeedZone`:** one violation per visit over the limit (+5 km/h tolerance).
  - **`OffRoadRule`:** more than a second off the GridMap's road tiles.
- **Crashes:** the car emits `crashed(impact_kmh)` when it loses more than 15 km/h within 0.05 s.
  Landings and bumps don't count; only horizontal speed is used.
- **Dialogue:** `violations()`, `ran_stop_sign()` and the new `crashes()` read the `LevelState`. New
  commands `<<fail_level "reason">>` and `<<level_event name>>` (a signal levels can hook up).
- **Test course:** a 50 km/h zone on the east straight, the off-road rule, and failing on 3
  violations or a crash.
- **Tests:** `test_rules.gd` (in CI) builds small scenes on the flat ground and drives through each
  rule, into a wall, and through the fail and restart.

**Still to do:**
- **Red lights:** need a traffic light model; the rule itself is a small `TrafficRule`.
- **Unanswered messages:** reply timeouts already work (`#timeout`); what ignoring someone costs is
  for writers (the timeout branch) plus `<<fail_level>>` where it should end the level.
- Hook a `<<level_event>>` to something in a level once a conversation needs one.
- **Found while testing:** at full throttle with no steering, the car drifts right (about 6 m over
  the first 150 m of the test course) and leaves the road. Worth a look in playtests: it may be the
  car's setup, or fine as "you have to steer".

### B4. Level flow (2–4 days)
- Level start → triggers (time/position) start threads → finish line → results screen (violations,
  messages sent, time) → next level
- Save story variables between levels, which is the seed of the persistent "metroidvania" layer

### B5. Streamer juice (only after the loop is fun)
- Physics chaos, crash slow-mo, absurd consequences, clip-friendly moments
- The "road-like / metroidvania" structure (run-based attempts, unlocks that open new routes or
  conversation branches) gets designed *after* the core loop is proven.

**Rough total:** about **4–6 weeks** of one programmer for B0–B4, running in parallel with Roadmap A after week 1.

---

## 5. Roadmap C: level builder

**Goal:** anyone on the team can make a playable level quickly, without editing scene files by hand or
knowing the code. It starts minimal and grows as levels need more.

### What exists today
- **Road kit** (`game/world/models/roads-v4.*`, July 2024): a GridMap tile set with 7 pieces: straight,
  turn, T-junction, crossroads, two ramps, and `CarRef`, a car-sized marker for scale. Tiles are 12 m
  square. Roads are painted tile by tile with Godot's GridMap editor.
- **Pieces with behaviour:**
  - Traffic rules (`rules/stop_sign.gd`, `speed_zone.gd`, `off_road.gd`, B3) and `LevelState`. A stop sign
    is still a zone, a collision shape and a model put together by hand in each level.
  - `Course` (B1): checkpoints, finish line, timer.
- **Two levels:** the ramps sandbox (`levels/main.tscn`, painted by hand) and the test course (B1).
  The test course came from a throwaway script that wrote the GridMap cells.
- **What's painful:**
  - Picking the right rotation for each turn tile. The rotations are numbers (0, 10, 16, 22), and
    working them out for the test course took trial renders.
  - Adding a stop sign or checkpoint means building an Area3D, a collision shape and a model by
    hand (rules no longer need their signals connected).
  - Nothing tells you a level is broken (checkpoint off the road, car spawning in a wall, stop sign
    facing the wrong way) until you drive it.
  - The road kit's source file (Blender?) isn't in the repo, only the exported `.glb`.

### C1. Level template and drag-in pieces (minimal, do first)
- `levels/level_template.tscn`: duplicate it to start a level. It contains sky and light, a `Roads`
  GridMap with the kit loaded, the car, and an empty `Course`.
- **Prefab pieces in `game/world/pieces/`**, dragged in from the FileSystem dock:
  - `Spawn` (where the car starts and which way it faces)
  - `Checkpoint` and `Finish` (the Course picks up their order automatically)
  - `StopSign` (trigger and model in one, already wired)
  - `TextTrigger`: drive into it to start a phone conversation (`thread`, `node` fields). This is the
    hook for B4's level flow and A5's `PhoneService`.
- **Pieces are visible in the editor** (labelled, coloured boxes, a "this way" arrow) and invisible
  in game, and snap to the 12 m road grid.
- **`docs/LEVEL_GUIDE.md`:** a one-page how-to (paint roads, drop pieces, press F6), written for
  designers, like the writing guide.

### C2. Level checker (same idea as the dialogue validator)
- **`tools/check_levels.gd`:** runs on every level in CI and when run by hand. It checks that:
  - there's exactly one spawn, and it's on a road tile;
  - every checkpoint and the finish sits across a road;
  - stop signs face oncoming traffic;
  - `TextTrigger`s name real Yarn nodes (cross-checked with the dialogue validator's entry points);
  - every checkpoint can be reached in order along the road.
- **Prints a per-level report:** road length, checkpoints, stop signs, conversation triggers, and an
  estimated drive time at the speed limit (so "a 3–5 minute level" can be checked).

### C3. Quick blockout from a text map
- **Sketch a level as text**, where each character is one road tile, then generate the level scene
  from it. For example:

  ```
  +----1---+
  |        |
  X        2
  |        |
  S        |
  F---3----+
  ```

  `-` / `|` road, `+` corner or junction, `S` spawn, `F` finish, `1–9` checkpoints, `X` stop sign.
- **Auto-tiling:** the generator picks the right tile and rotation from each tile's neighbours, which
  removes the rotation guesswork.
- **Then refine in the editor:** the text sketch is a fast starting point (and easy to discuss in a
  PR); after generating, designers refine in the editor as normal.

### C4. Later, when levels need it
- **Road painting with auto-tiling inside the Godot editor** (an editor plugin): draw a path and the
  plugin places the right tiles.
- **More road kit pieces** (traffic lights, lane markings, scenery, buildings) and more rule pieces
  (traffic lights, speed limits, school zones), each a drag-in prefab with a check in C2.
- **A level select screen** that lists every level automatically.

**Suggested order:** C1 → C2 → C3. C1 alone is enough for someone to build a level today. C2 stops
broken levels reaching playtesters, and C3 makes the first draft of a level take minutes.
The open questions for this roadmap are 2–4 in [Open questions](#open-questions).

---

## Suggested order of work

| Week | Programmer focus | Writers |
|---|---|---|
| 1 | B0 cleanup + 4.6 upgrade → **A0 spike** → A1 conventions → A2 setup | Read guide, start drafting in VS Code |
| 2 | A3 validation + CI, start B2 phone UI | Writing, using VS Code preview |
| 3 | A4 playtest scene (shares the phone UI from B2) | Playtest their scenes on the real phone |
| 4–5 | A5 integration, B1 driving cleanup, B3 coupling | Write level-specific hooks with programmers |
| 6+ | C1 level template + pieces, B4 level flow, first full prototype playtest | Iterate on what testers reach |

---

## Decisions

| Topic | Decision | Revisit when |
|---|---|---|
| Language | GDScript only, no C# | — |
| Engine | Upgrade to Godot 4.6.x | — |
| Writing tool | Yarn Spinner (script + VS Code graph view). A0 spike passed. | The plugin's early-access API breaks badly |
| Yarn addon install | Not committed (licence). Installed from a pinned commit by `tools/setup_yarn_spinner.sh` / `.ps1`. | — |
| Phone threads | One conversation shown at a time for the MVP; each contact runs separately so multiple live threads can be added later | After the prototype |
| Controls | **Hybrid:** gamepad drives the car, mouse and keyboard work the phone. Other schemes will be playtested too. | Playtests |
| Typing strictness | **Exact match** first, then experiment with typo-tolerance variants | Playtests |
| Message timing | **Timers:** NPC replies arrive a set time after the player's message. Level-gated delivery (timer *and* past a hidden marker) may be added later. | Timers prove not fun or hard to level-design |
| Writers | Comfortable with git; standard branch + PR workflow | — |
| Platform | Windows only | If other platforms become worth it |
| Branches | Descriptive names (e.g. `roadmap-doc`), merged to `main` by PR within the fork | — |
| World while phone is up | **Keeps moving.** Texting while the car is moving is the core challenge and the core marketing hook. | — |
| Texting and driving | **Full control of both at all times.** No "text mode" and "drive mode", and no artificial penalties for looking at the phone (no blur, no dampened steering). The challenge is emergent: switching attention between the road and the phone, like the real dangerous behaviour. | — |
| Hard-to-type characters | **Allowed** (emoji, unusual punctuation, etc.) as part of a difficulty curve where both texting and driving get harder in later levels | — |

## Open questions

1. **How are hard characters typed?** Options include an on-screen emoji picker, shortcodes
   (`:skull:`), or the phone's "long-press" alternate characters. This needs settling in B2, and the
   validation script (A3) should know which characters are allowed at each difficulty tier.
2. **Level builder: who builds levels?** People comfortable in the Godot editor, or should C3's
   text maps be the main tool?
3. **Level builder: where is the road kit's source file** (Blender?), and who can add pieces to it?
4. **Level builder: one long drive or loops?** The prototype goal is a 3–5 minute level.

---

### Sources (tool research, Oct 2026)
- Yarn Spinner for Godot, GDScript status: <https://yarnspinner.dev/docs/godot/>,
  <https://yarnspinner.dev/blog/monthly_jun_26>, <https://yarnspinner.dev/blog/monthly_jan_26/>
- Yarn Spinner VS Code graph view: <https://yarnspinner.dev/docs/yarn-spinner-editor/>
- Custom dialogue presenters: <https://yarnspinner.dev/docs/godot/06-components/02-dialogue-presenters/03-custom-dialogue-presenters/>
- inkgd (Ink in GDScript): <https://github.com/ephread/inkgd>
- articy:draft integrations: <https://www.articy.com/help/Integrations_Overview.html>,
  community Godot importer: <https://forum.godotengine.org/t/articy-to-godot-json-importer-and-player-addon/140370>
- Godot Dialogue Manager: <https://nathanhoad.itch.io/godot-dialogue-manager>
