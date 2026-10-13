#!/usr/bin/env python3
"""Serve Circuit Maze on this computer only and open it in a browser."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import webbrowser


def main() -> None:
    game_directory = Path(__file__).resolve().parent
    handler = partial(SimpleHTTPRequestHandler, directory=str(game_directory))
    with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print(f"Circuit Maze is running at {url}", flush=True)
        print("Press Ctrl+C to stop the game server.", flush=True)
        if "--no-browser" not in sys.argv[1:]:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nCircuit Maze stopped.", flush=True)


if __name__ == "__main__":
    main()
