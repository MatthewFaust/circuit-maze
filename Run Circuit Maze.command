#!/bin/zsh
cd -- "${0:A:h}" || exit 1
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is needed to run Circuit Maze locally."
  read -r "?Press Enter to close this window..."
  exit 1
fi
python3 run_local.py
