# Circuit Maze

A local, single-level robot maze prototype. Build a program by snapping together movement, loop, and path-check blocks, then run it to guide the robot to the flag. The 10×10 level includes grass, acid, fire, and impassable rock tiles.

## Run locally

On a Mac, double-click **Run Circuit Maze.command**. The game opens in your browser at a local `127.0.0.1` address. Keep the Terminal window open while playing; press **Ctrl+C** there to stop it.

Alternatively, with Python 3 installed:

```sh
python3 run_local.py
```

The game uses only files in this repository. It needs no ChatGPT account or internet connection. Your blocks are saved in the browser on this computer. **Load example** fills the workspace with a working route.

The block editor includes Blockly. Its license is in `vendor/LICENSE.blockly`.
