# Circuit Maze

A local robot maze game. Its first collection, **Intro**, has five beginner levels. Build a program by snapping together blocks, then run it to guide the robot to the flag. Use the level selector at the top to switch lessons; the task popup explains each new objective. These early levels use only safe floor and walls, introducing moves, turns, and repeats one step at a time.

The game uses [Blockly](https://developers.google.com/blockly) for its visual editor. Each maze is 10×10, and your programs and completed levels are saved in your browser.

## Play locally

On macOS, double-click **Run Circuit Maze.command**. Or, with Python 3 installed, run:

```sh
python3 run_local.py
```

The game opens at a local `127.0.0.1` address. Keep the Terminal window open while playing; press **Ctrl+C** to stop the server. It needs no ChatGPT account or internet connection.

To run the level checks, use `node --test` from this folder.

An optional [GitHub Pages demo](https://matthewfaust.github.io/circuit-maze/) is also available; the local version is fully playable on its own.

Blockly's license is included at [`vendor/LICENSE.blockly`](vendor/LICENSE.blockly).
