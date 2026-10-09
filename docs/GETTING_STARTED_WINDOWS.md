# Getting started on Windows

Step by step from a fresh Windows 10/11 install to:

- **playtesting** the current build (driving the test course and texting while you drive), and
- **writing** story scripts and hearing them on the phone in the car.

It takes about 30 minutes, mostly downloads. You need an internet connection and a GitHub account
with access to the fork, [`lwilsonxz/TextingWhileDriving-Luke`](https://github.com/lwilsonxz/TextingWhileDriving-Luke).
If you can't see that page, ask for access first.

Commands go in **PowerShell** (Start menu → type "PowerShell" → Windows PowerShell). After step 1,
**close and reopen PowerShell** so it picks up the newly installed tools.

---

## 1. Install the tools (once)

| Tool | What it's for | How to install |
|---|---|---|
| **Git** | Downloading the project and sharing your changes | Run `winget install --id Git.Git -e` in PowerShell, or use the installer from <https://git-scm.com/download/win> (the default options are fine). |
| **.NET 9 SDK** | Runs the Yarn compiler, which turns dialogue into something the game can play | `winget install Microsoft.DotNet.SDK.9`, or the installer from <https://dotnet.microsoft.com/download/dotnet/9.0> ("SDK", x64). |
| **VS Code** | Writing dialogue | `winget install Microsoft.VisualStudioCode`, or <https://code.visualstudio.com/> |
| **Godot 4.6.3** | Running the game | Manual download, below. |

**Godot:** use exactly 4.6.3, the **standard** build (not ".NET").

1. Go to <https://godotengine.org/download/archive/4.6.3-stable/> and download **Windows 64-bit**
   (a zip file).
2. Make a folder `C:\Godot` and extract the zip into it. You get two programs:
   `Godot_v4.6.3-stable_win64.exe` (the editor) and `Godot_v4.6.3-stable_win64_console.exe` (the same
   with a console window, used for command-line checks).
3. Make a copy of the console one in the same folder and name the copy `godot.exe`.
4. Add `C:\Godot` to your PATH, so `godot` works in PowerShell:
   1. Start menu → type "environment" → **Edit environment variables for your account**.
   2. Select **Path** → **Edit** → **New** → type `C:\Godot` → **OK**, then **OK** again.
5. Optional: right-click `Godot_v4.6.3-stable_win64.exe` → **Pin to Start**.

**The Yarn compiler**: reopen PowerShell, then run:

```powershell
dotnet tool install --global YarnSpinner.Console --version 3.2.2
```

**The Yarn Spinner extension for VS Code**: open VS Code → Extensions (`Ctrl+Shift+X`) → search
"Yarn Spinner" → **Install**.

**Check that everything is there.** Close and reopen PowerShell, then run these four commands. Each
should print a version, not "not recognized":

```powershell
git --version
dotnet --version     # should start with 9
ysc --version
godot --version      # should start with 4.6.3
```

---

## 2. Get the project (once)

```powershell
cd $HOME\Documents
git clone https://github.com/lwilsonxz/TextingWhileDriving-Luke.git
cd TextingWhileDriving-Luke
powershell -ExecutionPolicy Bypass -File tools\setup_yarn_spinner.ps1
```

The last command installs the Yarn Spinner add-on into the project. It isn't stored in the repo
because its licence doesn't allow that. It should end with `Installed Yarn Spinner (...)`.

The first time you run `git` it may ask for your name and email; set them with
`git config --global user.name "Your Name"` and `git config --global user.email "you@example.com"`.
The first push opens a browser window to sign in to GitHub.

---

## 3. Open it in Godot (once)

1. Start Godot (`Godot_v4.6.3-stable_win64.exe`). The **Project Manager** opens.
2. Click **Import** and select
   `Documents\TextingWhileDriving-Luke\TextingWhileDriving\project.godot`, then **Import** (or
   **Import & Edit**).
3. The first import takes a few minutes while Godot prepares the models, textures and dialogue.
   Some yellow warnings in the Output panel at the bottom are normal. **Red errors mentioning `ysc`
   or .NET** mean the Yarn compiler isn't found; see Troubleshooting.

---

## 4. Playtest

Press **F5** (or the ▶ button at the top right). The test course starts in its own window.

- **Controls:** the table under "Playing" in the [README](../README.md#playing). In short: arrow keys
  (or a gamepad) drive, **F4** (or LB) looks at the phone, click a reply on the phone, type the
  message exactly and press **Enter**.
- **You always control both.** The car keeps going while you text, and you can steer and brake
  while looking at the phone. The danger is where you choose to look.
- **What happens:** Mom texts just after the stop sign, with the placeholder conversation from the
  writing template. There's a stop sign, a 50 km/h zone on the far straight, and checkpoints. Three
  violations or a crash fails the level: press **R** (or Start) to try again.
- **Playtest options** (saved between sessions):
  - **F6** switches the phone glance between tap-to-toggle and hold.
  - **F7** moves the phone to the next spot in the car.
  - **F8** switches whether typing needs you to be looking at the phone.
- **Escape** quits.

Before playtesting new changes from others: `git pull`, then run the setup script from step 2 again
(it's quick, and needed whenever the add-on version changes).

---

## 5. Write a story script

The full rules are in the [writing guide](WRITING_GUIDE.md); read §2–§8 once. The short version:

1. **Open the project in VS Code:** File → Open Folder → `Documents\TextingWhileDriving-Luke`.
2. **Start from the template:** copy `docs\writing\template.yarn` to
   `TextingWhileDriving\dialogue\<Level>\<Thread>.yarn`, e.g. `dialogue\L1\Mom.yarn`, and replace the
   placeholder text.
3. **Declare story variables** (like `$mom_trust`) in `TextingWhileDriving\dialogue\Variables.yarn`.
4. **See it as a graph:** with the `.yarn` file open, press `Ctrl+Shift+P`, type "Yarn Spinner", and
   pick the graph view.

### Try it on the phone, without driving

1. Switch to Godot. It recompiles the dialogue when its window gets focus.
2. In the **FileSystem** panel (bottom left), open
   `game/debug/dialogue_playtest/dialogue_playtest.tscn`, then press **F6** (Run Current Scene).
3. Pick `dialogue/Dialogue.yarnproject` at the top, then double-click your first node.

There you can skip typing or delays, change story variables, and fake the driving ("ran the stop
sign"). See the writing guide §11.

### Hear it in the car

1. In Godot, open `game/levels/test_course.tscn` and click **MomTexts** in the **Scene** panel.
2. In the **Inspector** on the right:
   - **Yarn Project:** clear it (click the field's ↺ revert arrow) so it uses the game's dialogue.
   - **Node:** set it to your first node, e.g. `Mom_L1_Start`.
   - **Thread:** set it to who's texting, e.g. `Mom`.
3. Press **F5** and drive past the stop sign.

Only commit that change when your conversation is meant to be the course's. Otherwise put it back
(`git checkout -- TextingWhileDriving/game/levels/test_course.tscn`).

### Check it before sharing

From the project folder in PowerShell:

```powershell
godot --headless --script tools/validate_dialogue.gd
```

It lists any problems (`file:line: message`, with how to fix each), then a summary per file. CI runs
the same check on every pull request.

---

## 6. Share your work

Work on a branch with a descriptive name, then open a pull request **to this fork's `main`**. Never
open one against the original public project.

```powershell
git checkout main
git pull
git checkout -b mom-level-1          # a short name for what you're doing
# ...write, playtest, validate...
git add TextingWhileDriving/dialogue
git commit -m "Mom's level 1 conversation"
git push -u origin mom-level-1
```

The push prints a link. Open it to create the pull request, and check that the base is
`lwilsonxz/TextingWhileDriving-Luke` `main`. The checks run automatically and show any problems on
the PR. If you prefer buttons to commands, [GitHub Desktop](https://desktop.github.com/) does all of
this.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `godot`, `ysc` or `git` "is not recognized" | Close and reopen PowerShell. For `godot`, check the PATH step in §1 and that `C:\Godot\godot.exe` exists. For `ysc`, run the `dotnet tool install` command again. |
| Red errors in Godot about `ysc`, or "You must install or update .NET" | The Yarn compiler needs .NET 9. Install the .NET 9 SDK (§1), then **restart Godot** (it only sees new tools when it starts). If you have only .NET 10 or newer, run `setx DOTNET_ROLL_FORWARD Major` in PowerShell, then restart Godot. |
| Godot shows errors about `addons/yarn_spinner` or a missing plugin | Run the setup script again (§2), then restart Godot. |
| "running scripts is disabled on this system" | Run the setup script exactly as written in §2: the `-ExecutionPolicy Bypass` part allows it for that one command. |
| My `.yarn` change doesn't show up in the game | Switch to the Godot window so it recompiles, then check the Output panel for errors. Run the validator (§5) for a clearer message. |
| Nothing happens when I type on the phone | Look at the phone first (F4 or LB), or press F8 to allow typing without looking. Keys only type while a reply is being written. |
| The text on the phone is hard to read | Play fullscreen or in a bigger window, or try another placement (F7). Readability is still being tuned. |
