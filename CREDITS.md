# Credits

This file lists every image in the project, where it came from, and its license.

**Rule:** the project can't use AI-made art. Anything marked **AI-made, needs replacing** was created by Claude, an AI assistant, during development. Replace it with human-made or properly licensed art before release, then update its row here.

## Summary

| Source | Images | Status |
|---|---|---|
| Made by Claude (AI) | 62: every file in `art/` | AI-made, needs replacing |
| Godot Engine | 1: `icon.svg` | Not AI-made |
| Anywhere else | 0 | none |

**How this was checked (2026-10-13):**
- **Search:** I searched the whole project, outside Godot's `.godot/` cache, for image files of every common format.
  - There were 43 image files, all SVG. Every one is used by the game, except `floor.svg` and `stone.svg` (see below).
  - The `.svg.import` files beside them are Godot's import settings, not images.
- **The first 42 files in `art/`:** a Python script that Claude wrote generated all of them. The script is kept outside the repo.
- **Added later by Claude, written directly (2026-10-23):** `art/blocks/attack.svg` and `block.svg`, the 4 boss sprites in `art/bosses/`, the 4 skins in `art/robot/skin_*.svg`, the 8 gear pictures in `art/gear/`, `art/ui/portal.svg`, `art/ui/garage.svg`, and a redrawn `art/ui/star_empty.svg`. All are placeholders.
- **`icon.svg`:**
  - Its timestamp shows Godot created it with the new project, before Claude started working on the project.
  - Its text is identical to the default project icon built into Godot 4.6.1.

## From Godot Engine

| File | What it is | Source | License | Status |
|---|---|---|---|---|
| `icon.svg` | Project icon: game window, macOS Dock, Godot project manager | Godot Engine 4.6.1, which writes this default icon into every new project | **Artwork:** the Godot logo by Andrea Calabró, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **File:** ships with the Godot editor, [MIT license](https://godotengine.org/license/) | Not AI-made |

- **If you keep it:** credit it as "Godot Engine logo © 2017 Andrea Calabró, licensed under CC BY 4.0".
- **You'll probably want to replace it anyway:** it's Godot's logo, not art for this game.

## Made by Claude (AI)

**License:** none. No human artist made these, so there is no license to give. Every row has the same status.

**Sizes:**
- The tiles and the robot are 128×128 px.
- The icons are 48×48 px.

These are larger than the images appear on screen, so they stay sharp on high-resolution displays.

**Replacing an image:**
- Save the new image over the old file, at the same path.
- If the new file has a different name or format (for example `floor.png`), also update the `res://art/...` path in the scripts and scenes that load it.

### Tiles and robot

| File | What it is | Used in | License | Status |
|---|---|---|---|---|
| `art/tiles/floor.svg` | Floor tile | not used: the maze draws floor in the chapter's colors | None (AI-made) | AI-made, needs replacing |
| `art/tiles/stone.svg` | Stone wall tile | not used: the maze draws walls in the chapter's colors | None (AI-made) | AI-made, needs replacing |
| `art/tiles/bush.svg` | Bush tile (can be cut) | maze board, main menu background | None (AI-made) | AI-made, needs replacing |
| `art/tiles/exit.svg` | Exit tile | maze board | None (AI-made) | AI-made, needs replacing |
| `art/tiles/spike.svg` | Spike tile | maze board | None (AI-made) | AI-made, needs replacing |
| `art/tiles/battery.svg` | Battery pickup (+stamina) | maze board | None (AI-made) | AI-made, needs replacing |
| `art/tiles/repair.svg` | Repair kit pickup (+HP) | maze board | None (AI-made) | AI-made, needs replacing |
| `art/robot/robot.svg` | The robot, drawn facing east; also the "Starter Bot" skin | maze board, main menu logo, Garage | None (AI-made) | AI-made, needs replacing |
| `art/robot/skin_circuit_green.svg` | Placeholder skin "Circuit Green" (won from Raspberry Pi 3), facing east | maze board, main menu logo, Garage | None (AI-made) | AI-made placeholder, needs replacing |
| `art/robot/skin_sentinel.svg` | Placeholder skin "Sentinel" (won from Sensor Pi), facing east | maze board, main menu logo, Garage | None (AI-made) | AI-made placeholder, needs replacing |
| `art/robot/skin_rackmount.svg` | Placeholder skin "Rackmount" (won from The Server Stack), facing east | maze board, main menu logo, Garage | None (AI-made) | AI-made placeholder, needs replacing |
| `art/robot/skin_mainframe.svg` | Placeholder skin "Mainframe" (won from The Supercomputer), facing east | maze board, main menu logo, Garage | None (AI-made) | AI-made placeholder, needs replacing |

### Gear

Placeholders. Each picture is also worn on the robot as a small accessory (see `scenes/common/robot_gear.gd` for where it sits), and the weapons are drawn pointing east, the robot's facing. `data/progression.json` names each file, so new art can use any file name.

| File | What it is | Used in | License | Status |
|---|---|---|---|---|
| `art/gear/loop_blaster.svg` | Loop Blaster (weapon) | robot accessory, Garage shop, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/sensor_scope.svg` | Sensor Scope (weapon) | robot accessory, Garage shop, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/function_cannon.svg` | Function Cannon (weapon) | robot accessory, Garage shop, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/pathfinder_lance.svg` | Pathfinder Lance (weapon) | robot accessory, Garage shop, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/tin_shell.svg` | Tin Shell (armor) | robot accessory, Garage equipment, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/signal_shield.svg` | Signal Shield (armor) | robot accessory, Garage equipment, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/mirror_plating.svg` | Mirror Plating (armor) | robot accessory, Garage equipment, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |
| `art/gear/firewall_armor.svg` | Firewall Armor (armor) | robot accessory, Garage equipment, unlock notices | None (AI-made) | AI-made placeholder, needs replacing |

### Bosses

Placeholders: boss stages name their sprite in the level file (`"sprite"` in `boss`), and the skins are listed in `data/progression.json`, so new art can use any file name.

| File | What it is | Used in | License | Status |
|---|---|---|---|---|
| `art/bosses/raspberry_pi.svg` | Raspberry Pi 3, chapter 1 boss | 1-B board, level select | None (AI-made) | AI-made placeholder, needs replacing |
| `art/bosses/sensor_pi.svg` | Sensor Pi, chapter 2 boss | 2-B board, level select | None (AI-made) | AI-made placeholder, needs replacing |
| `art/bosses/server_stack.svg` | The Server Stack, chapter 3 boss (drawn smaller as it splits) | 3-B board, level select | None (AI-made) | AI-made placeholder, needs replacing |
| `art/bosses/supercomputer.svg` | The Supercomputer, chapter 4 boss | 4-B board, level select | None (AI-made) | AI-made placeholder, needs replacing |

### Block icons

These are shown on the blocks in the editor palette and in the program (`scenes/editor/block_catalog.gd`).

| File | What it is | License | Status |
|---|---|---|---|
| `art/blocks/move.svg` | `move()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/turn_left.svg` | `turn_left()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/turn_right.svg` | `turn_right()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/cut.svg` | `cut()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/backtrack.svg` | `backtrack()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/scan.svg` | `scan()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/scan_weighted.svg` | `scan_weighted()` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/repeat.svg` | `repeat` loop | None (AI-made) | AI-made, needs replacing |
| `art/blocks/while.svg` | `while` loop | None (AI-made) | AI-made, needs replacing |
| `art/blocks/if.svg` | `if` | None (AI-made) | AI-made, needs replacing |
| `art/blocks/if_else.svg` | `if / else` (same drawing as `if.svg`) | None (AI-made) | AI-made, needs replacing |
| `art/blocks/call.svg` | `call A/B/C` (functions) | None (AI-made) | AI-made, needs replacing |
| `art/blocks/attack.svg` | `attack()` (boss stages) | None (AI-made) | AI-made placeholder, needs replacing |
| `art/blocks/block.svg` | `block()` (boss stages) | None (AI-made) | AI-made placeholder, needs replacing |

### Interface icons

| File | What it is | Used in | License | Status |
|---|---|---|---|---|
| `art/ui/play.svg` | Play / Run | main menu Play button, level Run button | None (AI-made) | AI-made, needs replacing |
| `art/ui/pause.svg` | Pause | level Pause button | None (AI-made) | AI-made, needs replacing |
| `art/ui/step.svg` | Step | level Step button | None (AI-made) | AI-made, needs replacing |
| `art/ui/reset.svg` | Reset | level Reset button | None (AI-made) | AI-made, needs replacing |
| `art/ui/check_all.svg` | Check every map | level Check button | None (AI-made) | AI-made, needs replacing |
| `art/ui/back.svg` | Back arrow | level screen and level select Back buttons | None (AI-made) | AI-made, needs replacing |
| `art/ui/hint.svg` | Light bulb | level Hint button | None (AI-made) | AI-made, needs replacing |
| `art/ui/code.svg` | Code brackets | level Python button | None (AI-made) | AI-made, needs replacing |
| `art/ui/info.svg` | Info | level Briefing button | None (AI-made) | AI-made, needs replacing |
| `art/ui/heart.svg` | Heart | HP bar | None (AI-made) | AI-made, needs replacing |
| `art/ui/bolt.svg` | Lightning bolt | stamina bar | None (AI-made) | AI-made, needs replacing |
| `art/ui/dot.svg` | Dot | map tabs: map not tested yet | None (AI-made) | AI-made, needs replacing |
| `art/ui/check.svg` | Check mark | map tabs: map passed | None (AI-made) | AI-made, needs replacing |
| `art/ui/cross.svg` | Cross | map tabs: map failed | None (AI-made) | AI-made, needs replacing |
| `art/ui/undo.svg` | Undo | block editor toolbar | None (AI-made) | AI-made, needs replacing |
| `art/ui/redo.svg` | Redo | block editor toolbar | None (AI-made) | AI-made, needs replacing |
| `art/ui/trash.svg` | Trash can | block editor toolbar (drop a block here to delete it) | None (AI-made) | AI-made, needs replacing |
| `art/ui/close.svg` | × | delete button on every block | None (AI-made) | AI-made, needs replacing |
| `art/ui/gear.svg` | Gear | main menu Settings button | None (AI-made) | AI-made, needs replacing |
| `art/ui/lock.svg` | Padlock | level select: locked levels | None (AI-made) | AI-made, needs replacing |
| `art/ui/star.svg` | Filled star | level select, result dialog | None (AI-made) | AI-made, needs replacing |
| `art/ui/star_empty.svg` | Empty star | level select, result dialog | None (AI-made) | AI-made, needs replacing |
| `art/ui/garage.svg` | Toolbox | main menu and level select Garage buttons | None (AI-made) | AI-made placeholder, needs replacing |
| `art/ui/portal.svg` | Mysterious portal (a purple vortex) | level select: before each chapter's boss | None (AI-made) | AI-made placeholder, needs replacing |

## Not image files, but also made by Claude

These have no image or sound files, but they are visuals and sounds that Claude created in code. They are listed so that nothing AI-made is missed.

| What | Where | License | Status |
|---|---|---|---|
| **Board markers:** visited dots, breadcrumb trail, scan heat-map squares, fog | drawn with simple shapes by `scenes/maze/maze_view.gd` | None (AI-made) | AI-made, needs replacing |
| **Particle bursts:** bump sparks, cut leaves, win burst, power-down smoke, boss defeat | `scenes/maze/maze_view.gd` (plain colored squares, no texture) | None (AI-made) | AI-made, needs replacing |
| **Boss fight effects:** HP bars, hit flashes, the red glow before a strike, the shield ring | drawn with simple shapes by `scenes/maze/maze_view.gd` | None (AI-made) | AI-made, needs replacing |
| **Interface style:** panel and button shapes, borders | `ui/theme/main_theme.tres` (flat colored boxes, no images) | None (AI-made) | AI-made, needs replacing |
| **Chapter color themes (light and dark):** recolored interface, maze floor and walls, switch, radio and slider icons | `scenes/common/chapter_palette.gd`, palettes in `data/levels/catalog.json` | None (palette colors chosen by the project team) | Project-made |
| **Sound effects** | synthesized when the game starts by `autoload/sfx.gd` (there are no audio files) | None (AI-made) | AI-made, needs replacing |

The main menu background draws `bush.svg` over walls and floor in the chapter's colors, so it updates automatically when that tile is replaced.

## Fonts

No font files ship with the game. The theme asks the player's operating system for fonts that are already installed:
- **Text:** Avenir Next, Segoe UI, Helvetica Neue, Roboto, Arial or Sans-Serif.
- **Code view:** Menlo, SF Mono, Consolas, DejaVu Sans Mono, Courier New or Monospace.

## Engine

Made with [Godot Engine](https://godotengine.org) 4.6.1, which is MIT-licensed. Godot's license notice has to be included with any released build; see Godot's [Complying with licenses](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) page.
