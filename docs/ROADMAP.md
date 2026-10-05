# Texting While Driving: Prototype & Dialogue Tooling Roadmap

> Status: **reviewed draft**. Decisions so far are listed in [Decisions](#decisions) at the end.
> In short: GDScript only, Godot 4.6.x, Yarn Spinner for writing, Windows only, a gamepad drives
> while mouse and keyboard work the phone, typing must be exact at first, and replies arrive on timers.

This document has four parts:

1. [What's in the repo today, and what's worth keeping](#1-repo-audit)
2. [The dialogue tool recommendation](#2-dialogue-tool-recommendation)
3. [Roadmap A: dialogue creation pipeline (start now, unblocks writers)](#3-roadmap-a-dialogue-creation-pipeline)
4. [Roadmap B: minimum playable prototype](#4-roadmap-b-minimum-playable-prototype)

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

**Repo hygiene (do first, ~1 hour):**
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

### A0. Spike: prove the runtime (1–2 days, programmer)
In a scratch branch on Godot 4.6.x, install Yarn Spinner for Godot (GDScript) and confirm each item:
- [ ] A `.yarnproject` imports, and edits to `.yarn` files re-import on save
- [ ] A custom Dialogue Presenter receives lines, options and **hashtags** (`#delay:2`)
- [ ] Custom commands (`<<typing 3>>`) and functions (`<<if ran_stop_sign()>>`) call GDScript
- [ ] Variables can be read/written from game code and saved/loaded to disk
- [ ] Options with conditions, and "hidden" options we can auto-select on a timeout
- [ ] **Two dialogue runners at once**, sharing one variable store (needed for multi-thread later)
- [ ] It runs headless (`godot --headless`) so CI can validate files

**Go/no-go:** if two or more of these fail and can't be patched quickly, switch to the fallback above.

### A1. "Texting screenplay" conventions (1–2 days, programmer + lead writer)
This is a short `docs/WRITING_GUIDE.md`, and it's the main thing that unblocks writers. Draft proposal:

```yarn
title: Contact_Scene_Beat
---
<<thread Contact>>                  // which phone thread this conversation lives in
Contact: an incoming message        #delay:1.5
Contact: a second bubble            #delay:0.8
-> Short option label               // what the player picks (the "Mass Effect wheel" text)
    Me: the full message the player must type to send
    <<set $some_flag to true>>
    <<jump Contact_Scene_NextBeat>>
-> Another short label
    Me: a different message to type
    Me: players can be made to type multiple bubbles
    <<jump Contact_Scene_OtherBeat>>
-> (no reply) #timeout:10           // auto-picked if the player doesn't answer in time
    <<jump Contact_Scene_Ignored>>
===
```

Rules this format encodes:
- **NPC lines** (`Name: text`) appear as incoming bubbles. `#delay:` sets how long after the previous
  message (usually the player's reply) the bubble arrives. Timers are the only timing mechanism for
  now. An optional `<<typing N>>` shows the "…" indicator.
- **Later, if timers alone aren't fun or are hard to level-design around:** add level-gated delivery,
  e.g. `<<wait_for passed_bridge>>`, so a message arrives after its timer *and* only once the player
  has passed a hidden marker in the level. The format leaves room for this without changing existing files.
- **Options** are the short labels. The **`Me:` lines inside an option** are the exact text the
  player must type. Players never free-type; the typing challenge validates against these lines.
- **`#timeout:N`** on an option makes it the hidden default when the player doesn't reply. This is the
  bridge to driving pressure.
- **Gameplay hooks:** `<<command>>` for things the story *does* to the game (start a thread, trigger an
  event) and `function()` for things the story *asks* the game (did you crash? are you speeding?).
  Programmers own a list of available ones in the guide.
- **Naming:** node titles `Contact_Scene_Beat`, one file per contact per level, variables `$snake_case`.

Typing starts as an **exact match** (see Decisions). Still open for A1: whether `Me:` text can contain
emoji or punctuation that's hard to type.

### A2. Writer setup (½ day)
- Install VS Code + the **Yarn Spinner** extension and clone the fork (writers are comfortable with git).
- Folder layout: `TextingWhileDriving/dialogue/<level>/<contact>.yarn` plus one `.yarnproject`.
- Branch naming: descriptive names (e.g. `dialogue-mom-level1`), merged to `main` by PR.
- **Writers can start writing at the end of A1/A2**, using the VS Code graph + preview, before any
  game code exists.

### A3. Validation script + CI (2–3 days)
`tools/validate_dialogue.gd`, run with `godot --headless --script`, plus a GitHub Action on the fork:
- Yarn compiles (catches broken jumps, syntax errors, undeclared variables)
- Our conventions: every non-timeout option contains at least one `Me:` line; speakers are known
  contacts; only registered `<<commands>>`/functions are used; tags are well-formed
  (`#delay:<number>`); no unreachable nodes; at most one timeout option per choice
- A report of word count and branch count per file, so writers can see scope

### A4. Dialogue Playtest scene (3–5 days), the writers' main tool
`res://tools/dialogue_playtest.tscn` is a standalone scene that needs no driving:
- Pick any `.yarnproject` node from a list and play it in the **real phone UI**
- Toggle "skip typing" (auto-send) vs "real typing challenge"
- Variable inspector: view and edit `$variables` live, and fake gameplay functions
  (e.g. force `ran_stop_sign()` to return true)
- Restart from node, plus a history/back button
- Writers open Godot 4.6 and run this one scene (F6). Later we can ship it as a standalone build.

### A5. Runtime integration layer (3–5 days, overlaps with B2)
- `PhoneService` autoload: owns all threads, the shared story variables, and save/load
- `PhoneThread`: one per contact. It wraps a dialogue runner, stores message history, and emits
  `message_received`, `options_presented`, `typing_required`, `thread_finished`
- The MVP UI shows only the active thread. Because each contact already has its own runner and
  history, adding a thread list with notifications later is UI work, not a redesign.
- Gameplay registration: `PhoneService.register_function("ran_stop_sign", ...)`,
  `PhoneService.start_thread("Mom", "Mom_Level1_Intro")` from level triggers

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

### B0. Foundation (1–2 days)
- Repo hygiene from section 1, then upgrade to Godot 4.6.x
- Folder structure: `game/` (car, phone, levels, rules), `dialogue/`, `tools/`, `docs/`
- Input map for everything (no raw keycodes). Starting control scheme is the **hybrid**: a gamepad
  drives the car while mouse and keyboard work the phone. Keep driving and phone input in separate
  input actions so other schemes (keyboard-only, mouse steering) can be playtested by swapping bindings.

### B1. Driving core (3–5 days)
- Clean up `BaseCar.gd`: input map, sane speed units, tuning exports
- Camera: position/rotation preset pairs, with "glance at phone" vs "eyes on road" as the main toggle.
  A hold-to-look mode is worth testing.
- One course built from the GridMap road kit, plus start, checkpoints and finish trigger

### B2. Phone core (5–8 days)
- Phone UI in the existing SubViewport-on-quad: message bubbles, scrolling history, typing
  indicator, option buttons
- **Typing challenge:** show the target `Me:` text greyed out, fill it in as the player types
  (`InputEventKey.unicode`), handle backspace and mistakes, then "send". Start with **exact match**.
  Put the comparison behind one function (`TypingRule.check(target, typed)`) so typo-tolerance
  variants (ignore case/punctuation, allow N typos, typos get sent) can be swapped in for playtests.
- Mouse: tap options and the send button on the phone screen (the SubViewport needs mouse input
  forwarded from the 3D quad)
- Hook up to `PhoneService` (A5). Until A5 lands, drive it from a hard-coded test conversation.

### B3. The coupling: what makes it a game (4–6 days)
- **Distraction:** while looking at the phone, the road view is reduced (camera, blur or vignette) and
  steering input may be dampened
- **Traffic rules:** generalise `stopSign.gd` into a `TrafficRule` base (stop sign, red light, speeding,
  leaving the road) emitting violations to a `LevelState`
- **Texting pressure:** reply timeouts (`#timeout`) and unanswered-message consequences
- **Story ↔ gameplay:** violations and crashes are readable by dialogue functions; dialogue commands
  can trigger level events
- Fail conditions: N violations, a crash, or a story fail from a dialogue command

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

## Suggested order of work

| Week | Programmer focus | Writers |
|---|---|---|
| 1 | B0 cleanup + 4.6 upgrade → **A0 spike** → A1 conventions → A2 setup | Read guide, start drafting in VS Code |
| 2 | A3 validation + CI, start B2 phone UI | Writing, using VS Code preview |
| 3 | A4 playtest scene (shares the phone UI from B2) | Playtest their scenes on the real phone |
| 4–5 | A5 integration, B1 driving cleanup, B3 coupling | Write level-specific hooks with programmers |
| 6+ | B4 level flow, first full prototype playtest | Iterate on what testers reach |

---

## Decisions

| Topic | Decision | Revisit when |
|---|---|---|
| Language | GDScript only, no C# | — |
| Engine | Upgrade to Godot 4.6.x | — |
| Writing tool | Yarn Spinner (script + VS Code graph view) | The A0 spike fails |
| Phone threads | One conversation shown at a time for the MVP; each contact runs separately so multiple live threads can be added later | After the prototype |
| Controls | **Hybrid:** gamepad drives the car, mouse and keyboard work the phone. Other schemes will be playtested too. | Playtests |
| Typing strictness | **Exact match** first, then experiment with typo-tolerance variants | Playtests |
| Message timing | **Timers:** NPC replies arrive a set time after the player's message. Level-gated delivery (timer *and* past a hidden marker) may be added later. | Timers prove not fun or hard to level-design |
| Writers | Comfortable with git; standard branch + PR workflow | — |
| Platform | Windows only | If other platforms become worth it |
| Branches | Descriptive names (e.g. `roadmap-doc`), merged to `main` by PR within the fork | — |

## Open questions

1. **Does the world pause** when the phone is up? (I assume no; that's the premise.)
2. **Emoji and hard-to-type punctuation** in `Me:` lines: allowed, and if so how are they typed?

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
