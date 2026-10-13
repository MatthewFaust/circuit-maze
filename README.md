# Circuit Maze

A small browser game about programming a robot. Snap together movement, loop, and path-check blocks, run the program, and guide the robot to the flag while avoiding acid, fire, and rocks.

The game has a 10×10 level, a working example program, and browser-local saving. It uses [Blockly](https://developers.google.com/blockly) for the visual editor and runs entirely on your computer.

## Play locally

On macOS, double-click **Run Circuit Maze.command**. Or, with Python 3 installed, run:

```sh
python3 run_local.py
```

The game opens at a local `127.0.0.1` address. Keep the Terminal window open while playing; press **Ctrl+C** to stop the server. Choose **Load example** in the game to see a working route.

No account or internet connection is needed. Programs are saved in your browser on your computer.

Blockly's license is included at [`vendor/LICENSE.blockly`](vendor/LICENSE.blockly).
