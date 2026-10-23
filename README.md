# Robot Maze: Algorithm Escape

A single-player, stage-based puzzle game that teaches computer science algorithms.
A robot is trapped in a maze. You never steer it. Instead you build a program from
drag-and-drop blocks, press **Run**, and watch the robot carry it out step by step.

- **4 chapters, 22 levels and 4 bosses:** Sequencing & Loops → Conditionals & Sensors → Functions &
  Recursion → Maze Algorithms (wall following, DFS, BFS, and a Dijkstra bonus level). Each
  chapter ends with a boss fight that opens the next chapter.
- **Tiles:** floor (walk freely), **bush** (blocks the way until `cut()` destroys it),
  **stone** (never passable), spikes, batteries, repair kits and the exit
- **Health and stamina:** every action costs stamina; bumping stone or bushes and
  stepping on spikes costs HP
- **Several maps per level** from chapter 2 on: your program must pass all of them,
  like a test suite, so hard-coded move lists don't work

The full design (rules, architecture, every level) is in [PLAN.md](PLAN.md).

## Running the game

Open the project in **Godot 4.6** (standard build, no .NET needed) and press **F5**.
Main scene: `scenes/main_menu/main_menu.tscn`.

## How to play

| Control | What it does |
|---|---|
| Drag a palette block into the program | insert it where the colored line shows |
| Click a palette block | add it to the end of the active section (click a section header to choose one) |
| Drag a block back onto the palette (or the trash) | delete it; the × on a block does the same |
| `Ctrl/Cmd+Z`, `Ctrl/Cmd+Shift+Z` | undo, redo |
| **Run** / `Space` | run on every map (Space pauses too) |
| **Step** / `S` | run one action, then pause |
| **Reset** / `R` | stop and put the robot back |
| `1` `2` `3` `4` | speed 1x, 2x, 4x, max |
| **Check** | test every map instantly, without animation |
| **Hint** / `H`, **Python** / `C`, **JavaScript** / `J`, **Briefing** | hints, the program as Python or JavaScript code (one at a time; press the active one again to close it), the level intro |
| **Hint**, pressed again | each level has 3 hints: what to notice, the strategy, then the full solution as blocks. Each press shows the next one; once all three are showing, a press closes the card |

**Stars**:
- ★ escaped every map
- ★ total stamina used ≤ par
- ★ blocks used ≤ par

Each star is kept separately as your best result, and one star unlocks the next level.

**Boss fights**: the last stage of each chapter is a duel, not a maze. The robot has 20 HP;
`attack()` hits the boss in front for 2 damage plus your weapon's, and `block()` raises a shield
for one turn. Every boss strikes in a rhythm: on a strike turn the boss you face hits you for its
attack minus your defense (at least 1) unless you block, and a strike interrupts your attack.
`boss_ahead()` and `boss_charging()` read the fight. Bosses award no stars; each one unlocks a skin.

| Boss | HP | Attack | Teaches |
|---|---|---|---|
| Raspberry Pi 3 (1-B) | 16 | 5 | a fixed rhythm: repeat |
| Sensor Pi (2-B) | 30 | 7 | a different rhythm per arena: sensors |
| The Server Stack (3-B) | 20, splits into 2 × 10, then 4 × 5 | 9 | a tree of servers: recursion |
| The Supercomputer (4-B) | 80 | 13 | hidden in a maze: scan(), then fight |

**Gear and the Garage** (main menu or level select): gear only matters in boss fights.
- **Armor** comes free when you reach its stage and is equipped automatically: Tin Shell +1 defense (1-5), Signal Shield +2 (2-2), Mirror Plating +4 (3-4), Firewall Armor +8 (4-1).
- **Weapons** unlock in the **Shop** as your star total grows; stars are never spent. Equip any unlocked one: Loop Blaster +1 damage (15 ★), Sensor Scope +3 (27 ★), Function Cannon +9 (48 ★), Pathfinder Lance +15 (all 66 ★).
- **Skins** in the **Wardrobe** change only the robot's look. Beating a boss wins its skin and puts it on; the Starter Bot is always there.
- Every boss can be beaten with the armor you're given and no weapon. Better weapons let a less careful program survive.

Stars, gear, what's equipped and your skin are all saved.

**Colors**: each chapter has its own color theme, in a light and a dark version. Switch between them with **Settings → Dark mode** on the main menu; the choice is saved.

## Rules at a glance

| Action | Stamina | Notes |
|---|---|---|
| `move()` | 1 | Into stone: −15 HP, into a bush: −5 HP (robot stays). Spike: −25 HP. Battery +10 stamina, repair kit +30 HP |
| `turn_left()`, `turn_right()` | 1 | |
| `cut()` | 3 | Destroys the bush ahead (wasted if there is none) |
| `backtrack()` | 1 + turns | Pops the breadcrumb stack (DFS) |
| `scan()`, `scan_weighted()` | 5 | BFS / Dijkstra distance numbers from the exit (from the bosses in boss stages) |
| `attack()` | 1 | Boss stages: damage the boss ahead (2 + weapon); a strike that turn interrupts it |
| `block()` | 1 | Boss stages: no damage from a strike this turn |

Sensors are free:
- `path_ahead/left/right`, `bush_ahead`, `stone_ahead`, `spike_ahead`, `at_exit`
- `unvisited_*` (DFS)
- `closer_*` (after a scan)
- `boss_ahead`, `boss_charging` (boss stages)

A run fails when:
- HP hits 0
- stamina runs out
- the program ends before the exit
- a loop never reaches the exit (op/action limits)
- recursion goes too deep (stack overflow)

## Project layout

```
core/          game logic in plain GDScript (no nodes): rules, world, program model,
               interpreter, Python-like parser/printer, levels, evaluator, save data
data/levels/   catalog.json + one JSON file per level
autoload/      Game (scene switching, dev options), Progress (save file), Sfx (generated sounds)
scenes/        main_menu, level_select, level (screen, run controller, HUD, dialogs),
               maze (board drawing and animation), editor (drag-and-drop block editor)
ui/theme/      main_theme.tres: fonts, sizes and shapes (each chapter's colors come from its palette in catalog.json)
art/           SVG tiles, robot and icons (drawn on a 64-unit grid, rasterized at 2x)
tests/         headless test runner + suites      tools/level_report.gd  pars and stats per level
```

## Adding or changing a level

1. Write `data/levels/chN/N-M.json` (copy an existing level) and list it in `catalog.json`.
   - **Map legend:**

     | Char | Tile |
     |---|---|
     | `#` | stone |
     | `.` | floor |
     | `B` | bush |
     | `E` | exit |
     | `S` | start |
     | `^` | spike |
     | `+` | battery |
     | `H` | repair kit |
     | `M` | boss (boss stages; no exit needed) |
   - **Programs** (`solution`, `alt_solutions`, `anti_solutions`, `starter`) use the Python-like text form, one line per array item.
2. See how every program in the file performs:
   `Godot --headless --path . --script res://tools/level_report.gd -- --level=N-M`
3. Run the tests. The level tests check that:
   - the solution earns 3 stars
   - every anti-solution fails
   - replaying one map's moves doesn't solve a multi-map level
   - the maps are valid
   - a boss solution wins with the boss's `min_gear`, and an anti-solution's `passes_with` gear rescues it
4. **Boss stages** add a `boss` object: `name`, `sprite`, `skin`, `min_gear` (`armor`, `weapon`), and
   `units` (one per `M`, in reading order) with `hp`, `attack`, `pattern` (`O` open, `X` strike) and
   optional `split` children with a `cell`. A variant can set `boss_pattern`. Set `rules.max_hp` to 20.

## Tests

```bash
GODOT=/path/to/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --import          # after adding or renaming a class_name script
"$GODOT" --headless --path . --script res://tests/run_tests.gd   # exit code 0 = all passed
"$GODOT" --headless --path . --script res://tests/run_tests.gd -- --filter=test_levels
```

The suites cover:
- every rule and sensor
- the interpreter, including recursion and the infinite-loop limits
- the parser and printer (including a random round-trip test)
- save data
- all 22 levels
- UI smoke tests that simulate real mouse clicks and drag-and-drop in the block editor

## Developer options

Pass these after `--` when launching:
- `--level=2-3`: open a level directly
- `--program=solution|starter|empty`: load that program into the editor
- `--variant=2`: select a map
- `--steps=N`: run N steps instantly and pause
- `--autorun`: start running immediately
- `--speed=0`: max speed
- `--intro`: show the briefing dialog
- `--screen=garage`, `--tab=shop|equipment|wardrobe`: open the Garage
- `--hints=N`: open the hint card with N hints showing
- `--dark`: use dark mode for this run, without saving it
- `--result`: show the result dialog
- `--code`: open the Python view (`--code=js` for JavaScript)
- `--screen=select`: open the level select screen
- `--shot=/abs/path.png`: save a screenshot and quit
- `--unlock-all`: unlock every level
- `--save=user://dev.cfg`: use a separate save file

Example:
`Godot --path . -- --save=user://dev.cfg --level=4-4 --program=solution --steps=3`

## Notes for editing in Godot

- **Mouse filters:** `PanelContainer`, `Panel`, `Button` and plain `Control` nodes default to the mouse filter **Stop**. Inside the block editor, anything between a block and the editor root must be **Pass** or **Ignore**, or drag-and-drop silently stops working. The UI tests catch this.
- **Exporting:** add `*.json` to the export preset's *Filters to export non-resource files* so the levels are included.
