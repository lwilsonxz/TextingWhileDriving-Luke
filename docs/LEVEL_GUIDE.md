# Level guide

How to build a level in the Godot editor: paint the roads, drop in the pieces, press F6. No code
needed. (Setting up Godot: [GETTING_STARTED_WINDOWS.md](GETTING_STARTED_WINDOWS.md).)

---

## 1. Start from the template

1. In the **FileSystem** panel, open `game/levels/`.
2. Right-click `level_template.tscn` → **Duplicate…**, and name it after your level, e.g.
   `level_1.tscn`.
3. Double-click the new file to open it.

The template is a short straight road with everything a level needs:

| Node | What it is |
|---|---|
| `Roads` | The road tiles (a GridMap). |
| `Spawn` | Where the car starts and which way it faces. |
| `Course` | The timer, with `Checkpoint1` and `Finish` inside it. |
| `LevelState` | The driving record: violations, crashes, and when the level fails. |
| `OffRoad` | Counts leaving the road as a violation. |
| `car` | The player's car. Leave it anywhere: it's moved to `Spawn` when the level starts. |
| `WorldEnvironment`, `DirectionalLight3D` | Sky and sun. |

Press **F6** (Run Current Scene) to drive it. **F5** always runs the test course instead.

---

## 2. Turn on snapping (once)

So pieces line up with the road tiles:

1. In the 3D view's toolbar, turn on **Use Snap** (the magnet icon, or press **Y**).
2. **Transform** menu (top of the 3D view) → **Configure Snap…**: set **Translate Snap** to `6` and
   **Rotate Snap** to `90`.

Road tiles are 12 m square, so a 6 m snap puts a piece on a tile's centre or edge, and turns are
quarter turns.

---

## 3. Paint the roads

1. Click **Roads** in the **Scene** panel. The road kit appears in a panel at the bottom:
   - **RoadFlat:** a straight.
   - **RoadTurn:** a 90° corner.
   - **Road3Way:** a T-junction.
   - **Road4Way:** a crossroads.
   - **RoadUp1** and **RoadUp2:** ramps.
   - **CarRef:** a car-sized block for judging scale; don't use it as road.
2. Click a tile in that panel, then click or drag in the 3D view to paint. **Right-click** erases.
3. **Rotate** the tile before placing it: **S** turns it around the vertical axis (**Shift+S** turns
   it back). **W** resets the rotation.
4. Paint on the template's floor level, so the road surface is at ground height (the template sets
   this). Ramps go up a level.

Every road tile under the car counts as "on the road" for `OffRoad`, including its grass edges.

---

## 4. Drop in the pieces

Pieces are in `game/world/pieces/`. **Drag one from the FileSystem panel into the 3D view**, then
set it up in the **Inspector** on the right.

In the editor, each piece is drawn as a see-through coloured box with a label (and an arrow for
the direction of travel where that matters). In the game, only real art shows (the stop sign's
model); the rest are invisible.

| Piece | What it does | Settings |
|---|---|---|
| `spawn.tscn` (green, START) | Where the car starts. The arrow (blue axis, −Z) is forward. **One per level.** | Move it, turn it. |
| `checkpoint.tscn` (gold, CHECKPOINT n) | A gate the car must drive through, in order. | **Number:** 1, 2, 3… The Course finds every checkpoint itself, sorted by number, so they can be anywhere in the scene. |
| `finish.tscn` (white, FINISH) | Crossing it after every checkpoint finishes the level. **One per level.** | Move it, turn it across the road. |
| `stop_sign.tscn` (red, STOP) | Traffic must slow below 18 km/h in the zone, or it's a violation. Comes with the stop sign model. | Turn it so the arrow points the way traffic drives; the sign stands on the right. **Stop Speed Kmh.** |
| `speed_zone.tscn` (red, SPEED LIMIT n) | Going over the limit (+5 km/h) inside the zone is a violation, once per visit. Invisible in the game (no sign model yet). | **Limit Kmh**, **Tolerance Kmh**. To make it longer or shorter, select its `CollisionShape3D` and change the box size. |
| `text_trigger.tscn` (blue, TEXT) | Starts a phone conversation when the car drives through it, or a set time after the level starts. | **Thread** (who's texting), **Node** (where the conversation starts), **Yarn Project** (leave empty for the game's dialogue), **After Seconds** (−1 = when driven through). |

Pieces snap and rotate like anything else (§2). After changing a box size in the Inspector, reopen
the scene to refresh the coloured box.

---

## 5. Level settings

| Node | Setting | What it does |
|---|---|---|
| `LevelState` | **Max Violations** | Fail the level after this many traffic violations (0 = never). |
| `LevelState` | **Fail On Crash** | Fail the level when the car crashes. |
| `Course` | **Show Hud** | Show the timer and checkpoint count. |
| `OffRoad` | **Grace Seconds** | How long the car may be off the road before it counts. |

---

## 6. Before you share it

- [ ] One `Spawn`, on a road.
- [ ] One `Finish`.
- [ ] Checkpoints numbered 1, 2, 3… with no gaps or repeats.
- [ ] Every stop sign's arrow points the way traffic drives.
- [ ] Every text trigger names a real conversation node. Try the conversation in the dialogue
      playtest first (see the [writing guide](WRITING_GUIDE.md), §11).
- [ ] You drove it start to finish with **F6**.

Then share it like any other change: a branch, a commit and a pull request to this fork's `main`
(see the Windows guide, §6). CI loads every scene, so a level that errors when it loads is caught.

---

## Not here yet

From the roadmap's level builder plan (Roadmap C):

- **C2:** a level checker that catches the mistakes in §6 automatically.
- **C3:** sketch a level as a text map and generate it, with corners picked automatically.
- More pieces (red lights, more signs) as art and rules arrive.
