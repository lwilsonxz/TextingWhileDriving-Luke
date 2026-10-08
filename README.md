# Texting While Driving

A physics-y driving game where you text while you drive. Underneath the chaos, it's a story game
told through the conversations on your phone. Built with Godot 4.6 (GDScript only), for Windows.

- **Plans and decisions:** [`docs/ROADMAP.md`](docs/ROADMAP.md)
- **Writing dialogue:** [`docs/WRITING_GUIDE.md`](docs/WRITING_GUIDE.md)
- **Reading the code:** [`docs/CODE_TOUR.md`](docs/CODE_TOUR.md)

## Setup

1. **Godot 4.6.3** (the standard build, not .NET): <https://godotengine.org/download/archive/4.6.3-stable/>
2. **The Yarn compiler**, used to compile dialogue. Install the [.NET SDK](https://dotnet.microsoft.com/download)
   9 or newer, then run:
   ```sh
   dotnet tool install --global YarnSpinner.Console --version 3.2.2
   ```
   If you only have .NET 10 or newer, also set the environment variable `DOTNET_ROLL_FORWARD=Major`.
3. **The Yarn Spinner addon.** It isn't committed (its licence doesn't allow redistributing it), so
   install it once after cloning, and again whenever the pinned version changes:
   ```sh
   tools/setup_yarn_spinner.sh                                          # macOS / Linux / Git Bash
   powershell -ExecutionPolicy Bypass -File tools\setup_yarn_spinner.ps1   # Windows PowerShell
   ```
4. Open `TextingWhileDriving/project.godot` in Godot and press F5. The main scene is the test course
   (`game/levels/test_course.tscn`); `game/levels/main.tscn` is the old sandbox with ramps.

## Playing

| | Gamepad | Keyboard |
|---|---|---|
| Accelerate / brake & reverse | RT / LT | ↑ / ↓ |
| Steer | left stick | ← / → |
| Handbrake | B | Right Ctrl |
| Look at the phone | LB | F4 |
| Road / rear / left window view | D-pad ↑ / ↓ / ← | F3 / F1 / F2 |
| Pick a reply on the phone | | click it (while looking at the phone) |
| Type the reply / send / delete | | type / Enter / Backspace (while looking at the phone) |
| Try again after failing a level | Start | R |
| Quit | | Escape |

The test course has a stop sign, a 50 km/h zone on the far straight, and counts leaving the road.
Three violations or a crash fails the level. Mom texts just after the stop sign. For now that's the writing template's
placeholder conversation; it switches to a real one once writers add it to `dialogue/`.

Playtest options (saved between sessions): **F6** switches the phone glance between toggle and hold,
**F7** moves the phone to the next placement, **F8** switches whether typing needs a glance at the
phone.

## Layout

```
TextingWhileDriving/          the Godot project
├── dialogue/                 conversations, written in Yarn (see docs/WRITING_GUIDE.md), plus
│                             dialogue_hooks.gd: what dialogue can ask the game or tell it to do
└── game/
    ├── car/                  the car, its cameras and models
    ├── debug/                developer tools, e.g. the dialogue playtest scene
    ├── levels/               playable scenes (test_course.tscn; main.tscn is the ramps sandbox)
    ├── phone/                the in-car phone and its conversation UI
    ├── rules/                traffic rules, the level's record (LevelState), the course, conversation triggers
    ├── ui/                   menus and screens
    └── world/                roads, signs and other level pieces
tools/                        command-line tools and their tests
docs/                         roadmap, writing guide, spike results
spikes/                       throwaway experiments
```

## Checks

Run from the repo root. CI runs these on pull requests.

```sh
# Dialogue: compiles every conversation and checks the writing guide's rules
godot --headless --script tools/validate_dialogue.gd

# Scenes: loads and runs every scene, fails on any error (import the project once first)
godot --headless --path TextingWhileDriving --import
godot --headless --path TextingWhileDriving --script res://../tools/check_scenes.gd

# Dialogue playtest scene and phone UI, end to end
godot --headless --path TextingWhileDriving --script res://../tools/tests/test_dialogue_playtest.gd

# Car (driving at several frame rates, camera) and test course
godot --headless --path TextingWhileDriving --script res://../tools/tests/test_car.gd
godot --headless --path TextingWhileDriving --script res://../tools/tests/test_course.gd

# The phone in the car: a level starts a conversation, tap and type while driving
godot --headless --path TextingWhileDriving --script res://../tools/tests/test_phone.gd

# Traffic rules, crashes, failing and restarting a level
godot --headless --path TextingWhileDriving --script res://../tools/tests/test_rules.gd

# Validator tests
godot --headless --script tools/tests/test_dialogue_validator.gd
```

## Credits

- The car is based on [Car-Demo](TextingWhileDriving/game/car/CAR_DEMO_LICENCE.txt) by Manik Sharma (MIT).
- Dialogue runs on [Yarn Spinner](https://yarnspinner.dev) (Yarn Spinner Public Licence).
