# Writing Guide: the texting screenplay format

> Status: **agreed (roadmap step A1)**. Conventions here can still change; ask before
> working around one.

This is how conversations are written for the game. You write in plain text files using **Yarn**, a
screenplay-like format, in VS Code. VS Code shows the branches as a graph while you write. The
game turns these files into the conversations on the in-game phone.

- **Starting point:** copy [`docs/writing/template.yarn`](writing/template.yarn). It shows every
  feature on this page and compiles cleanly.
- **Yarn basics:** see the [official Yarn docs](https://docs.yarnspinner.dev/write-yarn-scripts).
  This guide only covers what's specific to this game.

---

## 1. Setup

1. Install [VS Code](https://code.visualstudio.com/) and the **Yarn Spinner** extension (search
   "Yarn Spinner" in the Extensions panel).
2. Clone the fork: `https://github.com/lwilsonxz/TextingWhileDriving-Luke`.
3. Open the repo folder in VS Code. To see a `.yarn` file as a graph, open it, then open the
   Command Palette (`Ctrl+Shift+P`) and type "Yarn Spinner" to find the graph command. In the graph
   you can drag nodes around and colour-code them, and it stays in sync with the text.

To also play conversations on the in-game phone (§11), follow the root README's setup: Godot 4.6.3,
the Yarn compiler, and `tools/setup_yarn_spinner` once.

---

## 2. Files and names

```
TextingWhileDriving/dialogue/
├── Variables.yarn          ← every story variable, declared once (see §7)
├── L1/
│   ├── Mom.yarn            ← one file per thread per level
│   └── BestFriend.yarn
└── L2/
    └── Mom.yarn
```

- **Thread:** one conversation on the phone, like a contact or a group chat. The game starts
  threads (e.g. "when the player reaches the bridge, start `Mom_L1_Start`").
- **Thread names** in file names and node titles have no spaces: the thread with John Doe is
  `JohnDoe.yarn` / `JohnDoe_L1_Start`, even though his messages are written `John Doe: …`.
- **Node titles:** `<Thread>_<Level>_<Beat>`, e.g. `Mom_L1_Start`, `Mom_L1_Ignored`,
  `Family_L2_Dinner`. Titles must be unique across the *whole game*, and the prefix keeps them
  unique. Use letters, digits and `_` only.
- **Branches (git):** `dialogue-<thread>-<level>`, e.g. `dialogue-mom-l1`. Open a PR into `main`.

---

## 3. Messages

| You write | On the phone | Notes |
|---|---|---|
| `Mom: are you driving?` | An incoming bubble from Mom | The name before the colon is the sender. Group chats just use several names in one thread. |
| `Me: no lol` | The player must **type** this, then it's sent | Exact text, see §5. |
| `System: Mom left the chat` | A small grey notice | For phone events ("Delivered", "Missed call", etc.). |

- **One message per line.** Several lines in a row become several bubbles.
- **Don't** write lines with no sender. Every line needs `Name:` (the validator will enforce this).
- **Sender names:** everything before the first `:` is the name, so names can be several words and
  include punctuation: `John Doe: hi`, `Dr. Jane O'Neil-Smith: hi`. **Don't put quotes around names.**
  `"John Doe": hi` is misread, and the line comes out garbled (tested). Colons later in the message
  are fine (`Mom: meet at 5:30`). The player is always `Me`.

---

## 4. Choices

```yarn
-> Make a joke
    Me: only at 90mph
    <<jump Mom_L1_Joke>>
-> Lie
    Me: nope, parked
    <<jump Mom_L1_Lie>>
```

- The text after `->` is the **short label** the player picks from (the "Mass Effect wheel" text).
  It is never sent as a message.
- The `Me:` lines indented underneath are what the player then has to **type** before it sends.
  **Every choice needs at least one `Me:` line** (except a timeout choice, §6).
- Several `Me:` lines means the player types several messages in a row.
- **Conditional choices:** add `<<if ...>>` after the label to only offer it sometimes:
  `-> Apologise <<if $mom_trust < 2>>`.
- **How many:** 1–4 visible choices. A single choice still makes the player pick it before typing,
  which is different from a forced reply (below), where there's nothing to pick.
- **Forced replies:** a `Me:` line *outside* a choice means the player has no choice, only something to type.

---

## 5. What the player types (`Me:` lines)

The player must type `Me:` text **exactly**. Typo tolerance will be playtested later, so for now write
exactly what should appear in the sent bubble, including capitals and punctuation.

**Typing difficulty.** Because the player types every `Me:` line while driving, the
characters in it decide how hard the message is to send. The plan is for typing to get harder in later
levels, so here is a rough scale for how hard each kind of character is to type:

| Difficulty | Characters | Why | Use |
|---|---|---|---|
| Easy | `a–z 0–9`, space, `. , ' -` | One key each, no Shift | Any level |
| Medium | Capitals, `? ! : ; " ( ) / & @ % ~ ^ \|`, digits mid-word (`gr8`) | Needs Shift, or hunting for a symbol | From the middle levels |
| Hard | emoji, accented letters (`é`), the escaped characters below | Not on the keyboard at all | Late levels. How players type emoji is still an [open question](ROADMAP.md#open-questions). |

This is only a guideline until levels have real difficulty targets. Later, the validator can warn
when a message is harder than its level allows.

**Characters that need a backslash** (in *any* line, not just `Me:`):

| To show | Write | Why |
|---|---|---|
| `#` | `\#` | `#` starts a tag. Unescaped, the rest of the line disappears. |
| `[` `]` | `\[` `\]` | Brackets are formatting markup. Unescaped, they scramble the line. |
| `{` `}` | `\{` `\}` | Braces insert variables. |
| `//` | `\/\/` | `//` starts a comment. Unescaped, the rest of the line disappears (`http://` breaks). |
| `\` | `\\` | |

`:` (after the sender), `%`, `<3`, emoji and accents need no escaping. These were all checked
against the real compiler and runtime.

---

## 6. Timing and timeouts

**Delays.** `#delay:N` at the end of an incoming message is the gap, in seconds, before it arrives,
counted from the previous message. The typing indicator ("…") shows during the gap.

```yarn
Me: on my way
Mom: drive safe #delay:4
```

- **No tag:** the game picks a natural delay from the message length (about 1–3 s).
- **Silence with no typing indicator:** `<<wait N>>` on its own line (someone looked away from their phone).
- Delays are on a timer for now. Later the game may also hold a message until the player
  reaches a spot on the road, but that won't change how these files are written.

**Timeouts.** A choice tagged `#timeout:N` is **hidden**. If the player hasn't picked anything after
N seconds, it's picked for them. This is how ignoring someone because you're driving gets consequences.

```yarn
-> (no reply) #timeout:15
    <<set $mom_trust to $mom_trust - 1>>
    <<jump Mom_L1_Ignored>>
```

- At most **one** timeout choice per set of choices. Its label isn't shown; write `(no reply)` for readability.
- It doesn't need a `Me:` line, since the player didn't reply.
- No timeout choice means the conversation waits until the player answers.

---

## 7. Story variables

Variables remember what happened (trust levels, lies told, who was ignored) across conversations
and levels, and are saved with the game.

- **Declare every variable once, in `dialogue/Variables.yarn`**, with a starting value and a comment
  (see [`docs/writing/Variables.yarn`](writing/Variables.yarn)). The compiler only *warns* about
  undeclared variables, so a typo like `$mom_turst` would silently create a new variable. The
  validator will turn this into an error.
- **Names:** `$<thread>_<what>`, snake_case (`$mom_trust`, `$mom_l1_answered`). Use
  `$story_<what>` for things not tied to one person.
- Set: `<<set $mom_trust to $mom_trust - 1>>`. Branch: `<<if $mom_trust < 2>> … <<endif>>`.

---

## 8. Asking the game things (and telling it to do things)

**Functions** let a conversation react to the driving: `<<if ran_stop_sign()>>`.
**Commands** let a conversation affect the game: `<<wait 5>>`.

Only use functions and commands from the list below; the validator rejects anything else. If you need
a new one, ask a programmer; adding one is quick. (Programmers: they live in
`TextingWhileDriving/dialogue/dialogue_hooks.gd` as `static func _yarn_function_*` / `_yarn_command_*`.
The validator reads them from there.)

| Name | Kind | What it does | Status |
|---|---|---|---|
| `<<wait N>>` | command | N seconds of silence, no typing indicator | ✅ available (built in) |
| `ran_stop_sign()` | function | true if the player ran the last stop sign | ✅ available |
| `violations()` | function | number of traffic violations this level | ✅ available |
| `crashes()` | function | number of times the player crashed this level | ✅ available |
| `<<start_thread Thread Node>>` | command | start another thread, e.g. a second contact texts in. For now the phone shows one conversation at a time, so it starts when the current one ends. | ✅ available |
| `<<fail_level "Reason">>` | command | the player fails the level; the reason is shown on the failed screen | ✅ available |
| `<<level_event name>>` | command | tell the level something happened in the story, e.g. `<<level_event mom_calls_police>>`. Ask a programmer to hook up what it does in the level. | ✅ available |

---

## 9. Tags reference

| Tag | Where | Meaning |
|---|---|---|
| `#delay:N` | incoming message | seconds before it arrives (§6) |
| `#timeout:N` | a choice | hidden choice auto-picked after N seconds (§6) |
| `#line:…` | any line | **added by tooling** for translation. Don't write or edit these by hand. |

Any other tag will be rejected by the validator, so if you want a new one, ask.

---

## 10. Before you open a PR

- [ ] Node titles follow `<Thread>_<Level>_<Beat>` and every `<<jump>>` goes to a real node
- [ ] Every choice has a `Me:` line (except a `#timeout` choice), and there's at most one timeout per choice set
- [ ] Every `$variable` is declared in `Variables.yarn`
- [ ] Special characters are escaped (§5)
- [ ] Only listed functions and commands are used (§8)

The **validator** checks all of this (and more) automatically on every PR that touches dialogue, and
shows problems inline on the PR. Each message says what's wrong and how to fix it.

To run it yourself before pushing (needs Godot 4.6 and the Yarn compiler, see §1), from the repo root:

```sh
godot --headless --script tools/validate_dialogue.gd
```

It lists problems as `file:line: error [code] message`, then a table per file: word counts, how many
characters the player types, and how many typed lines are easy/medium/hard (§5). It also lists the
**entry points**: nodes nothing jumps to, which the game must start. Check that this matches the
conversations you expect each level to start.

---

## 11. Playtesting on the phone

The **dialogue playtest** plays any conversation on the in-game phone, without driving.

1. Open `TextingWhileDriving/project.godot` in Godot 4.6.
2. Open `game/debug/dialogue_playtest/dialogue_playtest.tscn` and press **F6** (Run Current Scene).
3. Pick the Yarn project at the top. `dialogue/Dialogue.yarnproject` is the real game; the sample project
   is the template from this guide. Then double-click a node. ★ marks entry points, the nodes the
   game starts.

While it plays:

- **Typing:** click a choice, then type the `Me:` text and press Enter. Typos show in red and won't
  send. Tick **Skip typing** to send `Me:` lines automatically when you're checking the story, not
  the typing.
- **Timing:** `#delay`s play for real (with "… is typing"). Tick **Skip delays** to make messages arrive
  instantly.
- **Hidden choices are shown greyed out, with a note:** the `#timeout` choice (click it to test that
  branch, or wait for it to be picked) and choices whose `<<if>>` is false. Players never see these.
- **Story variables** can be changed at any time, e.g. set `$mom_trust` low to test that branch.
  **Reset variables** puts them back to their starting values.
- **Fake game state** decides what game functions return, e.g. tick `ran_stop_sign()` to play
  the "you ran the stop sign" branch.
- **Back** returns to the start of the previous node with the variables it had then. **Restart**
  replays from the first node.
- The **log** shows each node as it starts, and commands like `<<start_thread>>` that the game would run.

After editing a `.yarn` file, switch back to Godot (it recompiles automatically), then play again.

**In the car:** to hear a conversation while driving, a level needs a `TextTrigger` naming its thread
and first node (ask a programmer, or see `game/rules/text_trigger.gd`). It fires when the car drives
through it or a set time after the level starts. On the test course, Mom's trigger is just after the
stop sign.
