# Texting While Driving

A physics-y driving game where you text while you drive. Underneath the chaos, it's a story game
told through the conversations on your phone. Built with Godot 4.6 (GDScript only), for Windows.

- **Plans and decisions:** [`docs/ROADMAP.md`](docs/ROADMAP.md)
- **Writing dialogue:** [`docs/WRITING_GUIDE.md`](docs/WRITING_GUIDE.md)

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
4. Open `TextingWhileDriving/project.godot` in Godot. The main scene is `game/levels/main.tscn`.

## Layout

```
TextingWhileDriving/          the Godot project
├── dialogue/                 conversations, written in Yarn (see docs/WRITING_GUIDE.md)
└── game/
    ├── car/                  the car, its cameras and models
    ├── levels/               playable scenes (main.tscn is the test track)
    ├── phone/                the in-car phone, plus dialogue_hooks.gd (what dialogue can ask the game)
    ├── rules/                traffic rules (stop signs, ...)
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

# Validator tests
godot --headless --script tools/tests/test_dialogue_validator.gd
```

## Credits

- The car is based on [Car-Demo](TextingWhileDriving/game/car/CAR_DEMO_LICENCE.txt) by Manik Sharma (MIT).
- Dialogue runs on [Yarn Spinner](https://yarnspinner.dev) (Yarn Spinner Public Licence).
