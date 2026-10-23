# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Robot Maze: Algorithm Escape is a Godot 4.6 puzzle game that teaches CS algorithms to college intro students. It uses GDScript only (standard build, no .NET) and the GL Compatibility renderer.

The player never steers the robot. They build a drag-and-drop block program, and the robot runs it on every map variant of the level, like a test suite.

- `PLAN.md` is the design spec: rules, architecture and all 22 level designs.
- `README.md` is the guide for players and developers: controls, map legend, developer options.

## Commands

Godot isn't on PATH. On this machine it's `/Users/alexander/Downloads/Godot.app/Contents/MacOS/Godot`. Run these from the project root.

```bash
GODOT=/Users/alexander/Downloads/Godot.app/Contents/MacOS/Godot

# Rebuild the class cache. Required after adding or renaming a class_name script, or adding SVGs.
"$GODOT" --headless --path . --import

# Tests. Exit code: 0 = all pass, 1 = failures, 2 = stale class cache (run --import).
"$GODOT" --headless --path . --script res://tests/run_tests.gd
"$GODOT" --headless --path . --script res://tests/run_tests.gd -- --filter=test_parser
"$GODOT" --headless --path . --script res://tests/run_tests.gd -- --filter=test_levels.gd::test_anti_solutions_fail

# Per-map stamina, HP and blocks for every solution, alt and anti program in a level.
"$GODOT" --headless --path . --script res://tools/level_report.gd -- --level=4-2

# Play straight into a level with a throwaway save file.
"$GODOT" --path . -- --save=user://dev.cfg --level=2-3 --program=solution

# Screenshot, then quit. Needs a real window, so not --headless.
"$GODOT" --path . --windowed --resolution 1600x900 -- --save=user://dev.cfg --level=4-4 --program=solution --steps=3 --shot=/abs/path/out.png

# Animation frames via Movie Maker.
"$GODOT" --path . --windowed --resolution 1600x900 --fixed-fps 10 --quit-after 80 --write-movie /abs/dir/f.png -- --save=user://dev.cfg --level=1-4 --program=solution --autorun
```

**`--filter`:**
- It's a substring match on `file::method`, e.g. `test_levels.gd::test_anti_solutions_fail`.

**Errors fail tests:**
- The runner installs a `Logger`, so any engine or script error logged during a test fails that test.
- This matters because a GDScript runtime error doesn't stop the script. It only aborts the current function.

**Linting:**
- There is no linter.
- For a single file, use `--check-only --script res://path.gd`.
- It reports false errors for scripts that use the autoloads `Game`, `Progress` or `Sfx`. For those, rely on the test run: `test_ui.gd` loads every screen and every level.

**Developer options:**
- They go after `--`. Examples: `--variant=N` (1-based), `--steps=N`, `--autorun`, `--speed=0`, `--intro`, `--hints=N`, `--result`, `--code`, `--screen=select`, `--unlock-all`.
- The full list is in the header of `autoload/game.gd`.
- Always pass `--save=user://dev.cfg` so dev runs never touch the real progress file. That file is `user://progress.cfg`, in the custom user dir `RobotMazeAlgorithmEscape`.

## Architecture

There are three layers, and dependencies only point downward.

### 1. `core/`: simulation and language

These are `RefCounted` classes with `class_name`. They use no nodes and never reference autoloads, so all of the game logic runs and tests headless.

- **`MazeWorld`**
  - `apply_action(name)` changes the world and returns an `Array[Dictionary]` of events, such as `{"type": "moved"}`, `bumped`, `hp_changed`, `cut`, `scanned`, `won` or `failed`.
  - `sense(name)` evaluates a sensor and costs nothing.
  - Checks for each action run in this order: stamina → pay → effect → HP ≤ 0 fails → standing on the exit wins.
  - Every cost, damage amount and limit lives in `MazeRules`. A level's `rules{}` can override any key listed in `MazeRules.OVERRIDABLE`.
- **Programs**
  - Programs are plain Dictionaries. The shape is documented at the top of `program_model.gd`.
  - They're deep-copied for undo snapshots, and the interpreter gets its own copy, so editing never affects a run in progress.
  - Nodes get integer ids from `ProgramModel.assign_ids()`, and the ids are stripped before saving.
  - Lists are addressed by refs: `"main"`, `"fn:A"`, `"<id>:body"`, `"<id>:else"`.
  - Structural edits go through `ProgramModel` (`insert`, `remove`, `move_node`). `move_node` refuses to move a block into its own subtree.
- **`ProgramInterpreter`**
  - It uses an explicit frame stack, not GDScript recursion.
  - Each `step()` advances to exactly one action. It returns that action's events, plus `active_ids` (for highlighting) and `call_stack` (for the inspector).
  - Runaway programs end with a fail code instead of hanging: `op_limit`, `idle_loop`, `action_limit`, `stack_overflow` or `program_ended`.
- **`ProgramParser` / `ProgramPrinter`**
  - These read and write a Python-like text form of the same model (`for _ in range(N):`, `elif`).
  - Level files store programs in this form.
  - The in-game Python view uses `ProgramPrinter.render()`, which also maps node ids to line numbers.
  - Converting to text and back must be lossless; a test checks this.
- **Levels**
  - `LevelCatalog` reads `data/levels/catalog.json` → `LevelLoader` → `LevelData`. JSON floats are converted to ints once, at load.
  - `LevelVariant.make_world()` builds a fresh `MazeWorld` for each map.
  - **`LevelEvaluator.evaluate(level, program)` is the single authority for pass/fail and stars.** It runs every variant headlessly.
- **`ProgressData`** is the pure save model.

### 2. `autoload/`

- **`Game`:** the catalog, scene switching with a fade, and the developer command-line options.
- **`Progress`:** saves and loads `ProgressData` as a ConfigFile, with a debounced `queue_save()` and the settings.
- **`Sfx`:** synthesizes its WAV sounds at startup and stays silent when headless.

### 3. `scenes/`: views that only react to core output

- **`level/level_screen.gd`** wires it all together: `ProgramEditor` ↔ `RunController` → `MazeView`, `HudBars`, `InspectorPanel`, `LogLine`.
- **`RunController`**
  - Its loop: `interpreter.step()` → highlight the block → pass each event to the views → await.
    - Animated: `append_event(tween, e)`, with one Tween per step.
    - Max speed: `apply_event(e)`, no animation.
  - `MazeView`, `HudBars` and `LogLine` implement both methods. A new event type needs handling in each of them.
  - **Cancellation:** a generation counter, checked after every await, plus the `_step_over` signal. Never await SceneTree timers or a tween that may be killed.
- **The animated run is only a visualization.** When it ends, `level_screen` calls `LevelEvaluator.evaluate()` on the editor's program to show the result and record stars. **Check** does the same with no animation.
- **`editor/ProgramEditor`**
  - The program Dictionary is the only source of truth.
  - **Structural edits:** save an undo snapshot (`EditHistory`), change the model, then rebuild the views, deferred.
  - **Parameter edits** (repeat count, sensor, NOT): change the model in place, so the widget keeps focus.
  - **Drops:** only the `ProgramEditor` root implements `_can_drop_data` / `_drop_data`. It finds the target list and index from the mouse position.
  - `BlockFactory` builds all the block visuals.

## Levels

- Each level is one JSON file in `data/levels/chN/` and must be listed in `catalog.json`.
- Programs in level files (`solution`, `alt_solutions`, `anti_solutions`, `starter`) use the Python-like text form, one line per array item, with 4-space indents.
- **`test_levels.gd` enforces this contract for every level:**
  - the maps are valid
  - `solution` uses only allowed blocks, fits `block_limit`, and earns all 3 stars (stamina and blocks within `par`)
  - every alt solution escapes
  - every anti-solution fails, with `expect_fail_code` when one is given
  - replaying one map's action list fails the level, unless `checks.hardcode_must_fail` is false
  - with `checks.inline_must_fail`, inlining the function calls exceeds the block limit
- **Hints:** exactly 3 per level (the test enforces it). They go from a nudge, to the strategy, to an explanation of the full solution. `HintPanel` prints the level's `solution` as blocks (`ProgramPrinter.block_text()`) under the third hint, so never write the program into the hint text; update `solution` instead.
- **When a level fails, fix its map or its par, not `MazeRules`.** The rules are shared by all 22 levels.
- Use `tools/level_report.gd` to find the right numbers.

## Conventions and gotchas

**Code style**
- `.gd` files use tabs.
- `var x := <Variant>` is a parse error. Variant sources include Dictionary lookups, `json.data` and `max()`. Declare the type instead (`var x: int = d["k"]`) and use `maxi` / `clampi`.
- Comparing a String to an int with `==` is a runtime error.

**`class_name`**
- Use it only for scripts in `core/` and `scenes/`. Never use it in autoloads, tests or tools; test suites extend `"res://tests/suite_base.gd"` by path.
- Pick distinctive names that can't collide with Godot built-ins (`GridMap`, `Logger` and so on).

**`.uid` files and `uid=` values**
- Godot generates these. Never invent them. Commit the ones `--import` creates.

**Scenes**
- `.tscn` files are hand-written `format=3` text with `%UniqueName` nodes.
- Signals are connected in `_ready()`, never as `[connection]` entries.
- Anything repeated or driven by level data is built in code: blocks, palette, board, level buttons.

**Mouse filters in the block editor**
- `PanelContainer`, `Panel`, `Button` and plain `Control` default to STOP.
- Every control between a block and the `ProgramEditor` root must be PASS or IGNORE, or drops fail silently.
- Widgets that must keep STOP (buttons, SpinBox, OptionButton) hand drops up through `ProgramEditor.forward_drops(c)`.
- `test_ui.gd` catches regressions with simulated mouse drags.

**Godot quirks**
- Containers reset their children's `scale` and `position`, so animate a wrapper node or `modulate`.
- `set_pressed_no_signal()` doesn't unpress ButtonGroup siblings. Set each button explicitly.
- Don't free controls inside `_drop_data`. Defer the rebuild.

**Theme and art**
- Each chapter has its own color theme. Its five colors (`background`, `floor`, `path`, `accent`, `text`) are the chapter's `palette` in `data/levels/catalog.json`.
- `ui/theme/main_theme.tres` supplies fonts, sizes, margins and corner radii as type variations, such as `PrimaryButton`, `BlockMotion` and `HPBar`. Set `theme_type_variation` instead of hard-coding colors.
- **Its colors are not used at runtime.** `ChapterPalette` (`scenes/common/chapter_palette.gd`) copies the theme and replaces every color with a palette role from `STYLE_ROLES` / `COLOR_ROLES`. A new style or color in the theme needs a role there; `test_palette.gd` fails until it has one.
- Screens set their chapter theme in `_enter_tree()` so children build in the right colors (the main menu, the first scene, does it in `_ready()` once the autoloads are loaded). Each level-select card wears its own chapter's theme.
- Hand-drawn colors read roles from the theme type `Palette`: `get_theme_color(&"accent", &"Palette")`. Don't hard-code colors in scripts.
- `test_palette.gd` also checks WCAG contrast for text, blocks and buttons in every chapter, so palette changes can't make text unreadable.
- The theme and the SVGs in `art/` are the source files; no generator script is in the repo. The switch, radio and slider icons are drawn from SVG strings in `ChapterPalette`, because the engine defaults are white and icons can't be tinted by the theme.
- The SVGs are drawn on a 64-unit viewBox at 128×128, so they rasterize at 2× for Retina.

**Headless UI tests**
- The headless window is a scaled 64×64.
- `_send()` in `test_ui.gd` pushes events into the root viewport and mirrors the mouse position into `Input` in screen space.
- `_drag()` sets `gui_embed_subwindows = true` so Godot finds a drop target.
- Reuse these helpers for new UI tests.
- UI tests must swap in a temporary `ProgressData` (see `_use_temp_progress()`).

**Exporting**
- There's no export preset yet. When one is added, its *Filters to export non-resource files* must include `*.json`, or the levels won't ship.

**MCP server**
- `.mcp.json` configures the `godot` MCP server with a machine-specific `GODOT_PATH`. The Bash commands above work as well.
