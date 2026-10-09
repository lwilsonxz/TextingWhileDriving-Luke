# Art placeholders

Everything visual that was made by code or by a programmer (not an artist), so human artists can
replace it in the final game. Each item is also marked `ART PLACEHOLDER` in its file; to find them
all:

```sh
git grep -n "ART PLACEHOLDER"
```

**Rule for new work:** reuse existing art assets. If something visual has to be made or changed to
get a feature working, mark it `ART PLACEHOLDER` in the code and add it to this list.

## In the game (players see these)

| What | Where | What it is now | What the real version needs |
|---|---|---|---|
| **Phone screen UI** | `game/phone/conversation/chat_view.gd` | A mock-up made in code, loosely like a phone messaging app: colours, message bubbles, contact header, "… is typing", choice buttons, reply countdown bar, and the typing box (typed text dark, typos red, the rest grey). The colours and sizes are constants at the top of the file. | A designed phone UI: messages, choices, the typing challenge, the countdown. Probably a Godot Theme plus styled scenes. |
| **The phone itself** | `game/phone/phone.tscn`, `phone.gd` | A flat screen (a quad) with no phone body, shown unshaded so it's readable. It's scaled to real phone size, and `PhoneMount` places it in one of five spots in the car. | A phone model (case, bezel, maybe a hand or mount for each placement) with the screen as its display. |
| **Traffic warnings** | `game/rules/level_state.gd` | Red text at the top of the screen ("TRAFFIC VIOLATION: Ran a stop sign", "CRASH! (45 km/h)"). | Styled HUD warnings. |
| **"Level failed" screen** | `game/rules/level_state.gd` | A dark overlay with white text: the reason and "Press R (or Start) to try again". | A designed fail screen. |
| **Results screen** | `game/ui/results_screen.gd` | A dark overlay with "LEVEL COMPLETE", the time, violations (listed), crashes, messages sent and replies missed, plus Retry and Next level buttons, made in code. | A designed results screen. |
| **Title screen** | `game/ui/title_screen.gd` | The game's name in plain text on a dark background, with Continue / New game / Quit buttons, made in code. | A designed title screen (logo, background, menu). |
| **Timer and checkpoint HUD** | `game/rules/course.gd` | White text with an outline, top left: "0:42.1    Checkpoints 1/3", then "Finished in …". | A designed HUD. |
| **Checkpoints and finish line** | `game/world/pieces/checkpoint.gd`, `finish_line.gd` | Invisible in the game: no art existed. | Something to drive through: an arch, flags, cones, a chequered line, a banner. |
| **Speed limit zones** | `game/rules/speed_zone.gd`, `game/world/pieces/speed_zone.tscn` | Invisible in the game: there's no speed limit sign model. | A speed limit sign (the limit is a setting, so the number should be changeable). |
| **Playtest option note** | `game/settings.gd` | White text shown for 2.5 s when F6/F7/F8 change an option. | A debug aid. May not need art, or should go into an options menu. |
| **Sky** | `game/levels/test_course.tscn`, `level_template.tscn` | Godot's default procedural sky. | A real sky and lighting for each level's mood. |

## In the editor and tools only (players never see these)

| What | Where | What it is now | Notes |
|---|---|---|---|
| **Level piece markers** | `game/world/pieces/piece_marker.gd` | See-through coloured boxes, a direction arrow and a label (START, CHECKPOINT 2, STOP, SPEED LIMIT 50, TEXT: Mom), drawn only in the Godot editor. | Low priority: editor gizmos. Replace only if level designers want nicer icons. |
| **Dialogue playtest scene** | `game/debug/dialogue_playtest/` | Plain Godot controls in code: project picker, node list, variable and fake-state editors, log. | A writers' tool; low priority. |
| **Flat test ground** | `game/debug/car_test/flat_ground.tscn` | A large untextured plane for car tests. | Test-only. |

## Existing art (not placeholders)

For reference, the art that was already in the project and is reused:

- **Road kit** (`game/world/models/roads-v4.*`): straight, turn, T-junction, crossroads and two
  ramps. Levels paint it into a GridMap. Its source file (Blender?) isn't in the repo.
- **Stop sign** (`game/world/models/stop_sign_1.glb`, also `stop_sign_0.glb`): used by the stop sign
  piece.
- **The car** (`game/car/`, the Doge model and wheels), from the 2024 car demo, including the
  speedometer label on its HUD.
- **Ground texture** (`game/world/textures/texture_10.png`): used by the ramps sandbox (`main.tscn`).
- **Victory screen** (`game/ui/victory_screen.tscn`, 2024): no longer used. The old typing prototype
  that showed it was replaced in B2; the results screen (B4) took over its role. It's a single
  "YOU WIN" label, so there was nothing to reuse.

**Changed, not replaced:** the 2024 phone quad is now scaled to real phone size and placed by
`PhoneMount`. The ramps sandbox's texture reference was pointed at the source PNG (it pointed into
the import cache). Neither changed the art itself.
