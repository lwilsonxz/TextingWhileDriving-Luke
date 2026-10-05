# A0 spike: Yarn Spinner for Godot (GDScript)

**Verdict: GO.** Every feature the texting system relies on works. A few things need care, and they're
folded into later roadmap steps below.

- Tested with: Godot **4.6.3** (standard build), Yarn Spinner for Godot (GDScript) **Early Access 3.2**
  (commit `b4852f8`, pinned in `tools/setup_yarn_spinner.*`), `ysc` **3.2.2**
- Spike project: [`spikes/yarn-spinner/`](../../spikes/yarn-spinner/) (throwaway; delete once A5 lands)
- All dialogue in the spike is placeholder text written in the proposed texting format from roadmap A1

## Results

| # | Check | Result |
|---|---|---|
| 1 | `.yarnproject` imports; edits to `.yarn` files recompile on reimport | ✅ Pass. A changed line showed up after a normal reimport, with no cache clearing. |
| 2 | A custom presenter receives lines, options and hashtags | ✅ Pass. `Mom: text #delay:1.5` arrives as character `Mom`, text `text`, metadata `["delay:1.5"]`. Hashtags with `:` and `.` work. |
| 3 | Custom commands and functions call GDScript | ✅ Pass. `<<typing 0.2>>` pauses dialogue until its timer fires; `ran_stop_sign()` is called from an `<<if>>`. See the note on `static` below. |
| 4 | Variables can be read and written from game code, then saved and loaded | ✅ Pass. Variables were saved to JSON, loaded into a fresh runner, and a later conversation branched on them. |
| 5 | Conditional options, and a hidden option that is auto-selected on timeout | ✅ Pass. An option whose `<<if>>` is false arrives marked unavailable. A `#timeout:10` option arrives with that metadata, and choosing it runs its body and `<<jump>>`. |
| 6 | **Two dialogue runners at once** sharing one variable store | ✅ Pass. Mom and Dad threads ran in parallel with interleaved messages, and both wrote to the same store. |
| 7 | Runs headless (for CI) | ✅ Pass. All checks run with `godot --headless`. |
| — | The texting format: `Me:` lines inside options | ✅ Pass. The short option label isn't echoed, the `Me:` lines arrive as normal lines (character `Me`) with exact text and punctuation, and NPC replies follow. |

There's also an official **phone chat sample** (chat bubbles + typing indicator) and an
**options-that-timeout sample** in [YarnSpinner-Godot-Samples](https://github.com/YarnSpinnerTool/YarnSpinner-Godot-Samples).
Both are good references for B2 (phone UI). The samples are YSPL-licensed too, so we copy ideas, not files.

## Things to know (and where they go in the roadmap)

1. **Game hooks must be `static` functions to be global.** A method named `_yarn_command_x` /
   `_yarn_function_x` in a `class_name` script is auto-registered. If it's an *instance* method, Yarn
   treats it as an "instance command" that needs a target node name (`<<typing GameHooks 0.2>>`),
   which is clunky for writers. Making it `static` gives `<<typing 0.2>>`. → **A5:** all writer-facing
   commands/functions live as `static` methods on one `class_name` hooks script.

2. **Functions must be visible to the compiler before scripts compile.** A function registered at
   runtime with `add_function()` compiled with type `Any`, which breaks `<<if ran_stop_sign()>>`.
   The naming convention works because the plugin writes the signatures into the project's
   `.ysls.json`, which the compiler and the VS Code extension read. → **Commit the `.ysls.json`**
   (writers get autocomplete for game hooks). After editing hook scripts outside the editor, do a clean
   reimport (delete `.godot/`) to regenerate it.

3. **Yarn only *warns* about some real mistakes, and the importer doesn't surface warnings.**
   A `<<jump>>` to a missing node and an undeclared (typo'd) `$variable` are **warnings** in `ysc`,
   and an unknown `<<command>>` isn't reported at all (commands are resolved at runtime). The Godot
   import stayed silent and succeeded. → **A3 validator must:** run `ysc compile` and treat every
   warning as an error, and check every `<<command>>` against the `.ysls.json` list.
   Real compile errors (e.g. type errors) *are* reported clearly with file and line:
   `Mom.yarn: 12:5 if statement's expression must be a Bool, not a Any`.

4. **Load conversations before they're needed.** Creating a dialogue runner stalls a frame, and Godot
   then runs game time slightly fast for a few frames to catch up. A `<<typing 0.2>>` started right
   after a load finished in ~70 ms instead of 200 ms. After settling it was accurate (193–199 ms), and
   plain timers were always accurate. → **A5/B4:** create each level's runners at level start, never
   mid-drive.

5. **Saving variables needs a list of names.** Saving worked by reading known variable names. → **A5:**
   use the plugin's generated typed variable-storage class (one property per declared variable), or
   a custom `YarnVariableStorage` subclass, so save/load covers every variable automatically.

6. **Compiler setup.** The README says the addon bundles a native compiler, but the GitHub source
   doesn't include the binary (it builds from `native/build.sh` with .NET). The plugin falls back to
   the `ysc` command-line tool, which works and is what CI uses. **Anyone who opens the project in Godot**
   (programmers, and writers using the playtest scene) needs it once:
   - Install the .NET SDK 9 or newer.
   - Run `dotnet tool install --global YarnSpinner.Console --version 3.2.2`.
   - If only .NET 10+ is installed, set the environment variable `DOTNET_ROLL_FORWARD=Major`
     (`ysc` 3.2.2 targets .NET 9).

   Writers who only write in VS Code don't need it.

7. **Early-access risk is real but contained.** The plugin is labelled "do not ship yet", and the API
   may change. Everything we touch goes through `YarnDialogueRunner`, `YarnDialoguePresenter`,
   `YarnLine`/`YarnOption` and the variable storage, which A5 wraps behind `PhoneService`/`PhoneThread`.
   Upgrades are a one-line SHA change in the setup scripts.

## Licence notes (YSPL)

- **Free to use** in the game, commercial or not. Credit Yarn Spinner alongside the other tools.
- **Not committed to this repo:** the licence forbids redistributing unmodified source and the fork is
  public, so `addons/yarn_spinner/` is gitignored and installed by `tools/setup_yarn_spinner.sh` /
  `.ps1` from a pinned commit.
- **AI-training clause:** for this spike, Claude worked only from the addon's README, quickstart,
  changelog, licence and official samples, plus compiler/runtime output. It did not read the
  addon's internal source.

## How to run the spike

From the repo root (needs Godot 4.6.x and `ysc` as above; on Windows use `tools\setup_yarn_spinner.ps1`):

```sh
tools/setup_yarn_spinner.sh spikes/yarn-spinner
godot --headless --path spikes/yarn-spinner --import
godot --headless --path spikes/yarn-spinner        # exits 1 if any check fails
```

To test reimport, edit `dialogue/ReimportCheck.yarn`, run the import again, then pass the new text:
`godot --headless --path spikes/yarn-spinner -- --expect-reimport="your new text"`.
