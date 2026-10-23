# Robot Maze: Algorithm Escape (Godot 4.6, GDScript)

## Context
The user wants a single-player, stage-based educational game that teaches CS algorithms.

- **Core loop:** a robot is trapped in a grid maze. The player never steers it. They build a program from **drag-and-drop blocks**, press Run, and watch the robot carry it out step by step.
- **Tiles:**
  - **floor**: walk through freely
  - **bush**: blocks the way until CUT destroys it
  - **stone**: can never be passed or destroyed
  - **exit, spike, battery, repair kit**
- **Bars:** a **health bar** and a **stamina bar**.

The user's decisions:
- Drag-and-drop blocks.
- The audience is college intro CS students, so the game uses the real terms.
- 4 chapters with 22 levels in total: Sequencing & Loops, then Conditionals, then Functions & Recursion, then Maze algorithms (wall-following, DFS, BFS, and a bonus Dijkstra level).

An earlier session planned this game in Unity. The user has since set up this Godot project, so the design carries over to Godot.

Environment:
- **Project:** `/Users/alexander/Documents/Claude Code/game class/new-game-project` is a fresh Godot 4.6.1 project. It holds only `project.godot` and `icon.svg`, so there's no code to reuse.
- **Godot:** `/Users/alexander/Downloads/Godot.app/Contents/MacOS/Godot`. It's the standard build, which means GDScript.
- **Machine:** M1 MacBook Air with a Retina screen, macOS 12.
- **Look:** 2D top-down. I'll draw the art myself as SVG files, and they can be swapped out later.

## Game rules
Every number lives in `MazeRules`, and a level can override any of them.

| Action | Stamina | Effect |
|---|---|---|
| `move()` | 1 | Step forward. **Hitting stone or the edge:** bump, −15 HP, the robot stays put. **Bush:** bump, −5 HP. **Spike:** −25 HP each time the robot steps on it; spikes never go away. **Battery:** +10 stamina, capped at max; the battery is used up and the log shows any amount wasted. **Repair kit:** +30 HP, capped at 100, used up. **Exit:** you win immediately, even in the middle of a loop. |
| `turn_left()` / `turn_right()` | 1 | Turn 90°. |
| `cut()` | 3 | The bush directly ahead becomes floor. With no bush ahead, the stamina is wasted and a warning appears. |
| `backtrack()` (ch4) | turns (0–2, shortest way) + 1 | Pop the breadcrumb stack, face the previous tile and step onto it. Spikes hurt again. An empty stack fails with `backtrack_empty`. |
| `scan()` (ch4) | 5 | Breadth-first search (BFS) outward from the exit. Bushes count as walls. Every tile gets a number, and the numbers stay fixed until the next scan. |
| `scan_weighted()` (ch4 bonus) | 5 | Dijkstra's algorithm: entering a bush costs 4 (cut + move), every other tile costs 1. |

- **Sensors** cost nothing:
  - `path_ahead/left/right`: the tile is in bounds and isn't stone or a bush. Spikes and the exit count as paths.
  - `bush_ahead`, `stone_ahead`, `spike_ahead`.
  - `at_exit`: always false while the program runs, because reaching the exit ends the run. It exists so you can write `while not at_exit()`, and a tooltip explains this.
  - `unvisited_ahead/left/right`: a path tile the robot has never stepped on. The start tile counts as visited.
  - `closer_ahead/left/right`: true when `dist[n] + cost(n) == dist[here]`, meaning that step stays on a cheapest path. For a plain scan, this is the same as "the number is one smaller". All three are false before a scan.
- **Order of checks for each action:**
  1. If `stamina < cost`, fail with `no_stamina`. Landing exactly on 0 is fine.
  2. Pay the stamina.
  3. Apply the effect.
  4. If HP ≤ 0, fail with `hp_zero`.
  5. If the robot is on the exit, it wins.
- **Run limits** checked by the interpreter. Each one fails the run with its own message and a CS tip:

  | Code | Trigger |
  |---|---|
  | `program_ended` | the program finished but the robot isn't on the exit |
  | `action_limit` | more than 1000 actions |
  | `op_limit` | more than 20000 operations (every block run and every check counts) |
  | `idle_loop` | more than 2000 operations in a row with no action |
  | `stack_overflow` | call depth over `max_call_depth`, which defaults to 100 (level 3-5 uses 30) |
- **Variants:** each map variant is a test case. It starts fresh: full HP 100, its own max stamina, an empty stack and no scan.
- **Stars:** each star is saved separately as your best result.
  - ★ escape every variant
  - ★ total stamina spent across all variants ≤ par (batteries don't count against you)
  - ★ blocks ≤ par

  One star unlocks the next level.
- **Block count:** every block counts as 1. That includes `repeat`, `while`, `if/else` (counted once), calls, and each non-empty `define`. Conditions and NOT are free. The repeat count N can be 1–99.

## Block language
- **Actions:** move, turn_left, turn_right, cut, backtrack, scan, scan_weighted.
- **Control:** `repeat N`, `while COND`, `if COND`, `if/else COND`, and `call A/B/C`.
- **Functions:** each of A, B and C is defined in its own "define A" section stacked under main. They can recurse, and they can call each other.
- **Conditions:** one sensor plus an optional **not**. No AND/OR, `elif` or `stop` blocks; none of the 22 levels needs them.
- **Palette:** each level limits which blocks and sensors appear, and can set a block limit.

The program also has a **Python-like text form**:
- **Used by:**
  - the read-only **View as code** panel, which highlights the line that's running
  - the level files' reference solutions and anti-solutions
  - the tests
- **`ProgramPrinter`:**
  - prints `repeat N` as `for _ in range(N):`, so the output is valid Python
  - prints an else holding a single if as `elif`
- **`ProgramParser`:**
  - also accepts `repeat N:`, `elif` and `pass`
  - gives errors with line numbers in Python's wording, for example "expected an indented block" or "unknown sensor 'bush_ahaed', did you mean 'bush_ahead'?"
- Converting a program to text and back always gives the same program, and a test checks this.

## Architecture
The game logic is pure GDScript (`RefCounted` classes with no nodes and no autoload references), so the tests can run headless. Views only ever react to events.
```
res://
  core/   class_name with distinctive names (never GridMap/TileMap/Logger/Timer/... built-ins)
    tiles.gd          Tiles: tile enum, map legend, DIRS (0=N 1=E 2=S 3=W), is_walkable()
    maze_grid.gd      MazeGrid: PackedByteArray of cells; get_tile() returns STONE when out of bounds; from_rows() lists map errors
    robot_state.gd / maze_rules.gd     RobotState (pos, facing, hp, stamina) / MazeRules (all costs and limits, from_overrides)
    maze_pathing.gd   MazePathing: BFS and Dijkstra distance field to the exit, plus the order tiles were settled (drives the wave animation)
    maze_world.gd     MazeWorld: grid + robot + visited + trail (breadcrumb stack) + scan + revealed (fog) + stamina_spent;
                      apply_action(name) -> Array[Dictionary] events; sense(name) -> bool; status / fail_code / fail_message
    program_model.gd  ProgramModel (static): builds nodes, assign_ids, get_list(ref), insert / remove / move_node
                      (rejects moving a block into itself; corrects the index for moves within one list),
                      count_blocks, normalize (turns JSON floats into ints), validate(allowed), inline_calls, from_actions
    program_interpreter.gd  ProgramInterpreter: explicit frame stack (MAIN/BODY/REPEAT/WHILE/CALL), one action per step();
                      step() -> {status, node_id, active_ids, call_stack, loops, checks, events}; run_to_end()
    program_parser.gd / program_printer.gd   text form; render() -> {text, line_of[id]} so the code view can highlight lines
    level_data.gd (LevelData + LevelVariant.make_world())   level_loader.gd   level_catalog.gd
    level_evaluator.gd   static_check(level, program) and evaluate(level, program) -> results per variant + stars
    progress_data.gd     pure save model: best stars per criterion, best block count, the saved program
  data/levels/catalog.json + ch1/1-1.json … ch4/4-6.json
  autoload/  game.gd (scene switching with a fade + dev args), progress.gd (ConfigFile at user://progress.cfg, keeps ints typed), sfx.gd
  scenes/    main_menu/  level_select/  level/ (level_screen, run_controller, hud, log_line, inspector_panel, intro_dialog,
             result_dialog)  maze/ (maze_view, board_view, floor/mark/fog/fx layers, robot_view)
             editor/ (program_editor, block_factory, block_view, block_list_view, palette_item, block_styles, block_catalog,
             edit_history, code_view)
  ui/theme/main_theme.tres    fonts, sizes and shapes; colors come from each chapter's palette (scenes/common/chapter_palette.gd).
                              Blocks keep a hue per category (motion blue, control orange, sensing teal, functions purple,
                              algorithms green), softened to pastels on each chapter's light background
  art/tiles  art/robot  art/ui  SVG drawn on a 64×64 viewBox but sized 128×128, so it rasterizes at 2× and stays sharp on Retina
  tests/run_tests.gd (extends SceneTree) + test_*.gd (no class_name in tests/)   tools/level_report.gd (pars and stats per level)
```

### Key designs
- **Program model:**
  - Shape: `{"version":1,"main":[…],"functions":{"A":[…]}}`.
  - Each node: `{"id","type", count | cond{sensor,negate} | body | else_body | fn}`.
  - Ids are integers numbered in order through the tree. They are stripped before saving.
  - Lists are addressed by a ref: `"main"`, `"fn:A"`, `"12:body"`, `"12:else"`.
  - Undo is a `duplicate(true)` snapshot.
  - The interpreter runs on its own deep copy, so editing can never change a run in progress.
- **Interpreter:**
  - Each `step()` returns after exactly one action, or after hitting a limit.
  - `active_ids` lists the owner of every open frame, from the outside in. That includes the `call A` block that entered the current function. The editor highlights the running block strongly and its parent blocks lightly.
  - `call_stack` (e.g. `["main","A","A"]`) feeds the inspector panel, which makes recursion visible.
- **Block editor:** model-driven; the program Dictionary is the only source of truth.
  - **Structure edits:** each one saves an undo snapshot, changes the model, then rebuilds the view (deferred).
  - **Parameter edits:** SpinBox, sensor dropdown and NOT toggle change the model in place without a rebuild, so focus is kept.
  - **Drag sources:** `BlockView` and `PaletteItem` return `{"rmz":true,"kind":"new"|"move",…}` from `_get_drag_data`. The drag preview is offset so the grab point stays under the cursor.
  - **Drop handling:** only the `ProgramEditor` root implements `_can_drop_data/_drop_data`.
    - Every control in between is PASS or IGNORE.
    - Buttons, SpinBoxes and dropdowns hand drops up through `set_drag_forwarding`.
    - The root finds the target from the mouse position: the deepest `BlockListView` under the cursor, with the insertion index taken from the block centers.
    - Dropping on the palette or the trash deletes the block.
    - It refuses drops into the dragged block itself and new blocks past the limit.
  - **Drag feedback:** a single overlay line shows where the block will land. The list auto-scrolls near its edges. `NOTIFICATION_DRAG_END` clears the drag state.
  - **Other ways to edit:**
    - Click a palette block to append it.
    - Each block has an X button.
    - Undo is Cmd/Ctrl+Z, redo is Shift+Z.
  - **Block count:** shown as "Blocks 7 / 10 (par 6)".
  - **Locking:** while a run is going, the editor is locked with `mouse_behavior_recursive` on the content. The first edit after a run ends resets that run.
- **RunController:**
  - **Each step:**
    1. Highlight the running block.
    2. Create one Tween with `set_speed_scale(speed)`.
    3. Add each event's animation for the board, HUD, inspector and log.
    4. Add `tween_interval`.
    5. `await finished`.
  - **Speed:** 1×, 2× or 4×. **Max** applies events without animation, about 6 ms of work per frame.
  - **Controls:** Pause pauses the tween. Step runs a single step. Reset kills the tween and bumps a generation counter that is checked after every await. The loop never awaits SceneTree timers.
  - **Variants:** they run one after another. Each tab gets a ✓ or ✗, and the run stops at the first failure.
  - **Check all tests:** runs `LevelEvaluator` instantly.
- **Maze view:**
  - A clipped `Control` holds a `Board` (`Node2D`, 128-unit cells, `LINEAR_WITH_MIPMAPS`), scaled to fit and refit when resized, up to 0.75×.
  - `_draw()` paints floor, stone, visited dots and the breadcrumb trail.
  - Each object that changes is its own `Sprite2D`: bush, items, spike, exit, the robot, and the fog cells. BFS numbers are Labels.
  - Tween animations:
    - move
    - turn (always the short way)
    - bump lunge and shake
    - cut (scale and spin out, then leaves)
    - item pop on pickup
    - damage: a red flash and a floating "−15"
    - scan waves popping in
    - fog fading away
    - win: spin and confetti
    - lose: power down
- **Level screen** (1600×900 base, `canvas_items`/`expand` stretch, window starts maximized for Retina):
  - **Top bar:** Back, level title, HP and stamina bars with numbers, and a "?" button.
  - **Left side:** variant tabs, the maze, the inspector, the log line ("Bump! −15 HP"), and the run bar with Run, Pause, Step, Reset, speed, Hint, View code and Check all tests. The inspector shows the call stack in ch3 and the DFS breadcrumb stack and BFS queue in ch4.
  - **Right side:** the block editor (palette and program).
- **Scenes:**
  - The fixed layouts are hand-written `.tscn` files: `format=3`, no made-up UIDs, `%UniqueName` nodes, signals connected in `_ready`. The user can keep editing them in the Godot editor.
  - Anything repeated or driven by level data is built in code: blocks, palette, board, level buttons.
  - Screens:
    - Main menu.
    - Level select: 4 chapter rows, with locks and stars.
    - Level screen.
    - Intro dialog: tutorial text, a "CS note" and the new blocks.
    - Result dialog: stars pop in, plus the failure reason and tip, stats, and Retry / Levels / Next.
- **Sound:** the `Sfx` autoload creates about 12 short WAV sounds in code at startup, so no audio files are needed. This comes last, as polish.

## Levels: 22 total, one JSON file each
Each level file contains:
- `id`, `title`, `concept`, `intro`, `cs_note`, `hints[]`
- `allowed{blocks, sensors, functions, not}`, `block_limit`, `par{blocks, stamina}`
- `robot{stamina, hp}`, `rules{}` overrides, `fog`, `starter`
- `solution`: the program that sets the par. It must earn all 3 stars.
- `alt_solutions[]`: programs that must escape but may miss the pars. Example: the right-hand rule on 4-1.
- `anti_solutions[{name, program, expect_fail_code?}]`
- `checks{hardcode_must_fail, inline_must_fail}`
  - `hardcode_must_fail` defaults to true. It is false for 1-1, 1-2, 1-3 and 1-6, where the lesson isn't generality.
  - `inline_must_fail` applies only to ch3 solutions that don't recurse.
- `variants[{name, facing, stamina?, map[]}]`

On 3-5, 4-1, 4-2 and 4-3 the stamina par comes from the cheapest order of the checks, not the first order a player will try. Finding that order is the challenge behind the stamina star. Run `tools/level_report.gd` to compare the orders, then store the cheapest one as `solution` and the others as `alt_solutions`.

Map legend:

| Char | Tile |
|---|---|
| `#` | stone |
| `.` | floor |
| `B` | bush |
| `E` | exit |
| `S` | start (floor) |
| `^` | spike |
| `+` | battery |
| `H` | repair kit |

The maps, solutions and pars in the appendix were checked with a quick simulation of these rules while planning. **The headless level test has the final say.** If a level fails it, fix the map or the par, not the rules.

| # | Title | Teaches | Forced by |
|---|---|---|---|
| **Ch1 "Boot Camp": sequence & loops** ||||
| 1-1 | Hello, World | sequence (`move`) | tutorial |
| 1-2 | Right Turn, Clyde | relative turns, first bump | starts with a buggy program to fix |
| 1-3 | No Pain, No Gain | HP as a resource (spikes, repair kit) | stamina rules out the safe route |
| 1-4 | Loop de Loop | `repeat`, battery and its cap | block limit of 8 |
| 1-5 | Stairway | nested loops | block limit of 7 |
| 1-6 | Hedge Your Bets | `cut` vs. detour costs | stamina set to the exact optimum |
| **Ch2 "Eyes Open": conditionals & sensors** ||||
| 2-1 | Are We There Yet? | `while`, `path_ahead`, NOT | 3 variants, limit 5 |
| 2-2 | Shrubbery! | `if/else`, `bush_ahead` | 3 variants, stamina budget |
| 2-3 | Winding Road | nested decisions, `path_left/right` | 3 variants, limit 6 |
| 2-4 | Overgrown | handling every case (path, bush, wall) | 3 variants, limit 8 |
| 2-5 | Spike Lanes | `spike_ahead`, deciding by context | 3 variants, HP |
| **Ch3 "Name It, Reuse It": functions & recursion** ||||
| 3-1 | Copy, Paste, Regret | `define`/`call` | sensors off; limit 24 (loops alone need 27) |
| 3-2 | Same Trick, Any Direction | picking the right abstraction | sensors off; limit 21 |
| 3-3 | Hedge Trimmer, Inc. | a function hiding a loop and a decision | 3 variants, limit 14 |
| 3-4 | Echo | recursion as memory (no variables) | 3 variants, stamina budget |
| 3-5 | Tiny Stack, Big Tree | tree recursion vs. tail recursion | no loops; call depth limit 30 |
| **Ch4 "Lost in the Labyrinth": maze algorithms** ||||
| 4-1 | Hand on the Wall | wall-following (right-hand rule) | 3 tree mazes, limit 8 |
| 4-2 | Island Trap | DFS: `unvisited_*` + `backtrack` | 3 variants that defeat all 6 fixed-priority followers |
| 4-3 | Lights Out | DFS in fog (no scan allowed) | fog, 3 mazes with loops |
| 4-4 | Ripple | BFS: `scan` + `closer_*` (a flow field) | 3 open rooms, stamina budget |
| 4-5 | Race the Clock | BFS beats DFS on cost | a mirrored pair of mazes, budget 20 |
| 4-6 | Toll Roads (bonus) | Dijkstra: `scan_weighted` | a mirrored pair, budget 30 |

The level tests check every level. They prove each one can be solved **and** that it really requires the concept it teaches:
1. The maps are valid: rectangular, exactly one S, at least one E, and the exit reachable. In ch4, S has an open tile ahead, left or right.
2. The reference solution uses only allowed blocks, fits the limit, wins every variant, and earns 3 stars. Every alt solution escapes.
3. Every anti-solution fails.
4. Replaying the solution's fixed list of actions from any one variant fails the level (unless the level is marked as a tutorial).
5. On ch3 levels, the solution with its function calls copied inline goes over the block limit.
6. Running the same program twice gives the same result.

## Project setup changes
- **`project.godot`, replaced:**
  - Name "Robot Maze: Algorithm Escape", main scene `res://scenes/main_menu/main_menu.tscn`.
  - Features `"4.6","GL Compatibility"`, with `renderer/rendering_method(.mobile)="gl_compatibility"`.
  - Remove the Jolt and d3d12 lines; they only matter for 3D and Forward+.
  - Autoloads `Game`, `Progress`, `Sfx`, and the custom theme.
  - Viewport 1600×900, `window/size/mode=2` (maximized), stretch `canvas_items`/`expand`.
  - `config/use_custom_user_dir=true` with the folder name `RobotMazeAlgorithmEscape`, since the game name has a colon.
  - `[importer_defaults] texture={"mipmaps/generate": true}`, so large mazes still look smooth when scaled down.
- **`.mcp.json`:** add `"GODOT_PATH": "/Users/alexander/Downloads/Godot.app/Contents/MacOS/Godot"` to the godot server's `env`. The MCP server can't find Godot in ~/Downloads on its own. This takes effect after Claude Code restarts, and Bash covers everything until then.
- **Test and capture runs:** use a separate save file (`--save=user://dev.cfg`) so they never touch the player's progress.

## Godot 4.6 gotchas to follow
- **Typing:**
  - `var x := dict["k"]`, `json.data`, `max()` and similar return Variants, so inferring a type from them is a compile error by default. Declare the type instead, for example `var x: int = …`, and use `maxi`, `clampi` and the like.
  - Don't override native methods (`get`, `set`, `get_name`) or redeclare `size`/`position`.
  - JSON numbers come back as floats, so convert them once, when loading.
  - `==` between a String and an int is a runtime error.
  - Use `posmod` for facing math.
- **Class names:** after adding or renaming any `class_name`, run `--import`. Don't put `class_name` on autoloads, tests or tools.
- **UI mouse handling:**
  - Plain `Control`, `Panel`, `ColorRect` and Buttons default to the mouse filter STOP. Any of these between a block and the editor root silently swallows the drop, and every overlay must be IGNORE.
  - Don't free controls inside `_drop_data`; defer the rebuild instead.
- **Animation:**
  - Containers reset a child's `scale`, so animate wrapper nodes or `modulate`.
  - A Tween with no tweeners never emits `finished`.
- **Scene files:** use `split_offsets` (in 4.6, `split_offset` is deprecated). `load_steps` isn't needed. Never invent `uid=` values or `.uid` files.
- **Formatting:** `.gd` files use tabs. The robot language's text form uses 4 spaces.

## Milestones (each one ends with its checks passing)
1. **Setup:** project settings, folder layout, `--import`, and an empty test runner that exits 0.
2. **Game rules:** Tiles, MazeGrid, RobotState, MazeRules, MazePathing, MazeWorld, plus one test for each rule in the rules table.
3. **Programs:** ProgramModel, the interpreter, the parser and the printer. Tests cover every block, every limit or failure code, recursion, and the text round trip.
4. **Levels:** loader, catalog, evaluator, all 22 level JSON files, `test_levels`, and `level_report`. This milestone checks the rules against the designed numbers early.
5. **Screens:** theme, SVG art, main menu, level select, the level screen layout, and drawing the maze. Dev arguments plus a screenshot hook.
6. **Running:** RunController, animations, HUD, variant tabs, result dialog, stars, and saving progress.
7. **Block editor:** click to add, drag and drop, parameters, undo, the block limit, highlighting, View as code, and locking while running.
8. **Teaching layer:** intro dialogs, CS notes, hints, the inspector (call stack, DFS stack, BFS queue), fog, Check all tests, and the starter program in 1-2.
9. **Polish:**
   - sound effects
   - extra "juice" (animation feedback)
   - settings (volume, reduce motion, unlock all)
   - an optional web export preset with the `*.json` include filter. Godot's 4.6.1 export templates have to be downloaded first, and I'll ask before downloading them.

## Verification
```bash
GODOT=/Users/alexander/Downloads/Godot.app/Contents/MacOS/Godot
PROJ="/Users/alexander/Documents/Claude Code/game class/new-game-project"
"$GODOT" --headless --path "$PROJ" --import        # after any new/renamed class_name or SVG (run twice the first time)
"$GODOT" --headless --no-header --path "$PROJ" --script res://tests/run_tests.gd; echo "exit=$?"   # 0 = all pass
"$GODOT" --headless --no-header --path "$PROJ" --check-only --script res://core/maze_world.gd      # parse check for one file
```
- **Unit and level tests:**
  - The runner compares the class list against `REQUIRED`. If the class cache is stale, it exits with 2 and prints the fix.
  - It counts script errors with an `OS.add_logger()` Logger. Godot doesn't stop a script when one occurs, so a test that logs an error counts as failed.
  - Any `SCRIPT ERROR` or `Parse Error` in the output is a failure.
- **UI smoke test:** headless, open each screen and each level, wait a few frames, and confirm no errors were logged. Then drive the editor through its public API (`append_new`, `delete_node`, `set_param`, undo) and simulate one palette → program drag with `Viewport.push_input`, checking that the model changed.
- **Screenshots** (needs a window, not headless). Save PNGs to the scratchpad and inspect them with Read, covering:
  - every screen
  - one level per chapter, partway through a run
  - the result dialog
  - drag feedback

  For example: `"$GODOT" --path "$PROJ" --windowed --resolution 1600x900 -- --level=4-4 --program=solution --steps=3 --shot=<scratchpad>/4-4.png`.
- **Animation check:** Movie Maker writes numbered PNG frames, for example: `--windowed --resolution 1600x900 --fixed-fps 10 --quit-after 80 --write-movie <scratchpad>/movie/f.png -- --level=1-4 --program=solution --autorun`. Check moves and turns, the bump shake, the bush being cut, the bars changing, the scan waves (4-4) and the win banner.
- **Manual playtest** (for the user, via F5 in the editor):
  - Solve 1-1 to 1-4 by dragging blocks.
  - Trigger each failure message: out of stamina, destroyed, program ended, infinite loop, stack overflow.
  - Check that stars and the saved program are still there after restarting.
  - Try 4-2 with the right-hand rule (it fails), then with DFS (it passes).

---

## Appendix: level designs from planning (S facing given; `[N,E,S,W]`)

### Ch1
- **1-1** `#######/#S...E#/#######` E. Solution: 4× `move()`. Anti-solution: 3 moves. Stamina 10, par 4/4.
- **1-2** E. Starts with the same program but left and right swapped: it bumps 5 times, HP drops to 25, and it doesn't reach the exit. Stamina 12, par 8/8.
  ```
  #######
  #S.####
  ##.####
  ##...E#
  #######
  ```
  Solution: `move, turn_right, move, move, turn_left, move, move, move`.
- **1-3** E. Stamina 10, par 6/6.
  ```
  #########
  #.......#
  #.#####.#
  #S^^H^^E#
  #########
  ```
  - Solution: 6× move. HP 100→50→80→30.
  - Anti-solution: the top route costs 13 stamina, more than the 10 available.
- **1-4** E. Max stamina 20, limit 8, par 26/8.
  ```
  #############
  ###E........#
  ###########.#
  ###########.#
  ###########+#
  ###########.#
  ###########.#
  #S..........#
  #############
  ```
  - Solution: `repeat 10: move` / `turn_left` / `repeat 6: move` / `turn_left` / `repeat 8: move`. The run needs 26 stamina: 6 left before the battery, 16 after it, 4 left at the end.
- **1-5** E. Limit 7, stamina 25, par 23/7.
  ```
  ###############
  #############E#
  #############.#
  #########.....#
  #########.#####
  #####.....#####
  #####.#########
  #S....#########
  ###############
  ```
  - Solution: `repeat 3: [repeat 4: move] turn_left [repeat 2: move] turn_right`. The win happens partway through a loop.
- **1-6** E. Stamina 20, set to the exact optimum; par 20/14.
  ```
  ###############
  ########...####
  ##.....#.#.####
  #S.BBB...B..E##
  ###############
  ```
  - Solution:
    ```
    move
    turn_left
    move
    turn_right
    repeat 4: move
    turn_right
    move
    turn_left
    repeat 2: move
    cut
    repeat 4: move
    ```
  - Anti-solutions: cut everything (23), never cut (25).

### Ch2
- **2-1** L-shaped corridors, (east, north) = (3,5), (6,2), (8,4), all facing E. Example: `#########/#######E#/#######.#/#S......#/#########`.
  - Solution: `while path_ahead(): move` / `turn_left` / `while path_ahead(): move`. Limit 5, stamina 20, par 31/5.
- **2-2** Corridors walled above and below, facing E:
  ```
  #S..B...B..E#
  #S.BB.....E#
  #SB.B.B.B..E#
  ```
  - Solution: `while not at_exit(): if bush_ahead(): cut() else: move()`. Stamina used: 16, 15, 22. Stamina 25, limit 5, par 53/4.
  - Anti-solutions: moving only (bumps until destroyed); cutting then moving every step (out of stamina).
- **2-3** Facing E, N, E. Stamina 40, limit 6, par 63/6.
  ```
  #########  #########  ###########
  #S..#####  ##E...###  #S........#
  ###.#####  #####.###  #########.#
  ###....##  #.....###  #.........#
  ######.##  #.#######  #.#########
  ##E....##  #S#######  #........E#
  #########  #########  ###########
  ```
  - Solution: `while not at_exit(): if path_ahead(): move() else: (if path_left(): turn_left() else: turn_right())`.
- **2-4** Same maps as 2-3 with bushes. Facing E, N, E. Stamina 50, limit 8, par 90/8. Never place a bush right after a left corner.
  ```
  #########  #########  ###########
  #SB.#####  ##EB..###  #S..B.....#
  ###.#####  #####.###  #########.#
  ###..B.##  #..B..###  #....B....#
  ######.##  #.#######  #.#########
  ##E.B..##  #S#######  #..B.B...E#
  #########  #########  ###########
  ```
  - Solution: the 2-3 program with `if bush_ahead(): cut()` added between the path_ahead check and the path_left check.
- **2-5** Two lanes, facing E. Stamina 30, limit 12, par 70/10.
  ```
  #################   ##############   ############
  #S.^^....^^....E#   #...^^....^.E#   #S..^...^^^#
  #.....^^....^^..#   #S^....^^...^#   #.^...^...E#
  #################   ##############   ############
  ```
  - Solution:
    ```
    while not at_exit():
        if spike_ahead():
            if path_left():
                turn_left(); move(); turn_right()
            else:
                turn_right(); move(); turn_left()
        else:
            move()
    ```

### Ch3
- **3-1** E. Limit 24, stamina 48, par 45/20. Sensors off.
  ```
  ########################
  ###...##...#...###...###
  #S..#....#...#.....#..E#
  ########################
  ```
  - Solution: `def A(): move, turn_left, move, turn_right, move, move, turn_right, move, turn_left, move`, with main `move, A, move, A, A, move, move, A, move`.
- **3-2** E, a clockwise square. Limit 21, stamina 88, par 85/19. Sensors off.
  ```
  #############
  ###...#...###
  ##S.#...#..##
  ##########..#
  ###########.#
  ####...###..#
  ##...#.E##.##
  #..#######..#
  #.#########.#
  #..#######..#
  ##..#...#..##
  ###...#...###
  #############
  ```
  - Solution: A = the same 10 steps as in 3-1; main = `repeat 3: [A, A, turn_right]`, then `A, turn_right, move, A`.
- **3-3** Variant 2 shown, facing E. Limit 14, stamina 40, par 105/12. No `path_left/right`. Each wrong branch is a dead end holding 2 spikes.
  ```
  #################
  ##############.##
  ##############^##
  ##############^##
  ##############.##
  ####.^^........##
  ########.#####.##
  ########B#####B##
  ########.#####.##
  ########.#####E##
  #S.B..B..########
  ########.########
  ########^########
  ########^########
  ########.########
  #################
  ```
  - Variants 1 and 3 have the same layout with the bushes moved.
  - Solution: `def A(): while not stone_ahead(): if bush_ahead(): cut() else: move()`, with main `A, turn_left, A, turn_right, A, turn_right, A`.
- **3-4** "Echo". N = 2, 4, 6 (N=6 shown), facing E. Stamina 16, par 33/9.
  ```
  ##########
  #######.##
  #######.E#
  #######.##
  #######..#
  #######.##
  #######..#
  #######.##
  #S......##
  ##########
  ```
  - The two pockets below E are decoys.
  - Solution: `def A(): if path_ahead(): (move, A, move) else: turn_left`, with main `A, turn_right, move`. Cost is 2N+3.
  - Anti-solutions: checking every pocket (out of stamina); a version with no base case (stack overflow).
- **3-5** Facing N. No while or repeat; only the `path_ahead` sensor; call depth limit 30. Stamina 130, par 110/18.
  ```
  ############
  #######.####
  #######.####
  #######.####
  ####E...####
  ###.###....#
  ###.##..####
  ###.#.#.####
  ###........#
  #...##.#####
  ###..#.#####
  ###.########
  ###S########
  ############
  ```
  - Solution:
    ```
    def A(): if path_ahead(): move, turn_left, A, turn_right, A, turn_right, A, turn_left, B
    def B(): turn_left, turn_left, move, turn_left, turn_left
    main: A
    ```
    This left-first order uses 112 stamina, with a peak call depth of 15. Calling straight first gives 110, the par, so store that one as `solution`.
  - Anti-solution: a tail-recursive wall follower. It overflows the stack at depth 30.
  - Level rule: `rules.max_call_depth=30`.

### Ch4
- **4-1** Facing E, S, S. Limit 8, stamina 60, par 105/7.
  ```
  #########  #########  #########
  #S....#.#  #S#.....#  #S#.....#
  #####.#.#  #.#.###.#  #.###.#.#
  #.....#.#  #...#.#.#  #...#.#.#
  #.#####.#  #####.#.#  ###.#.#.#
  #...#E..#  #.....#.#  #...#E#.#
  ###.###.#  #.###.#.#  #.#####.#
  #.......#  #..E#...#  #.......#
  #########  #########  #########
  ```
  - The right-hand rule: `while not at_exit(): if path_right(): turn_right(); move() else: (if path_ahead(): move() else: turn_left())`. It uses 48, 43 and 42 stamina, so it goes in `alt_solutions`.
  - The left-hand mirror uses 32, 37 and 36, a total of 105, which is the par. It is the `solution`.
  - Anti-solution: the 2-3 follower, which loops forever.
- **4-2** Facing E, W, W. Limit 10, stamina 50, par 65/8.
  ```
  ############  ############  ############
  #E........##  ##........E#  ######E#####
  ###.#####.##  ##.#####.###  ###.......##
  ###.#####.##  ##.#####.###  ###.#####.##
  ###.#####.##  ##.#####.###  ###.#####.##
  ###...S...##  ##...S...###  ###...S...##
  ############  ############  ############
  ```
  - Solution (DFS):
    ```
    while not at_exit():
        if unvisited_ahead(): move()
        else:
            if unvisited_left(): turn_left()
            else:
                if unvisited_right(): turn_right()
                else: backtrack()
    ```
    This ahead, left, right order uses 17, 17 and 35 stamina (69 in total). Every one of the 6 orders wins.
  - The cheapest order sets the par, about 65. Confirm it with `level_report`.
  - Anti-solutions: the right-hand rule loops on variants 2 and 3; the left-hand rule loops on variant 1.
- **4-3** Fog on, facing E, W, E. No scan allowed. Stamina 150, par 185/8.
  ```
  ###########  ###########  ###########
  #E....#...#  #.......#E#  #E......#.#
  #.#.#.###.#  #.#####.#.#  #.#####.#.#
  #...#.....#  #.....#...#  #.....#...#
  #.#.#.###.#  #.###.#.#.#  #.###.#.#.#
  #.#.#S....#  #.#..S#...#  #.#S..#...#
  #.#.#.#####  #.#.#.#.###  #.#.#.#.###
  #.#.#...#.#  #.#.......#  #.#.......#
  #.#.#.#.#.#  #.#.#####.#  #.#.#####.#
  #.........#  #.........#  #.........#
  ###########  ###########  ###########
  ```
  - Solution: the 4-2 DFS. That order uses 36, 103 and 70 stamina (209). The par of about 185 comes from the cheapest order, so confirm it with `level_report`.
  - Anti-solutions: both wall followers loop; DFS without `backtrack` spins in place.
- **4-4** One room, facing N. Stamina 20, par 40/7.
  ```
  ###########
  #.........#
  #.#.#.#.#.#
  #....E....#
  #.#.#.#.#.#
  #S........#
  ###########
  ```
  - Variant 2: S top-right facing S, E on the middle row at column 3. Variant 3: S at the left of the middle row facing E, E on the top row at column 7.
  - Solution: `scan()`, then `while not at_exit(): if closer_ahead(): move() else: (if closer_left(): turn_left() else: turn_right())`.
- **4-5** Variant A shown, facing N. Variant B is A mirrored left-right. Stamina 20, par 32/7.
  ```
  ###############
  ###.....#######
  #######.....###
  #######.#######
  #####...##....#
  #######.##.####
  #E...##.##....#
  ####.##.##.####
  ####...S...##.#
  ###############
  ```
  - BFS costs 16 on both variants. Every DFS order and wall follower fails one of the two (about 100 stamina).
- **4-6** Variant A shown, facing E. Variant B is A flipped top to bottom. Stamina 30, par 56/9.
  ```
  ###############
  #####.....#####
  #####.###.#####
  ##....###....##
  ##.#########.##
  #S..BBBBBBB..E#
  ##.#########.##
  ##.....B.....##
  ###############
  ```
  - Solution: `scan_weighted()`, then `while not at_exit(): if closer_ahead(): (if bush_ahead(): cut()) move() else: (if closer_left(): turn_left() else: turn_right())`. Cost 5 + 23 = 28.
  - Anti-solutions: plain `scan` costs 33; cutting straight through costs 33.

**Texts:** each level's intro and CS note is 1–3 sentences, concise, slightly playful, and uses the real terms. Two examples:
- 4-2: "Any rule that only looks at its surroundings can be trapped in a loop. DFS adds memory: a visited set plus a stack of breadcrumbs."
- 4-4: "BFS uses a queue, so it labels tiles in order of distance; walking downhill on those numbers is a shortest path, the same 'flow field' games use for pathfinding."
