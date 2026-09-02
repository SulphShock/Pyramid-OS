#!/bin/bash
# open nautilus in cwd of focused window (jq-free; uses python3)
pid=$(hyprctl activewindow -j | python3 -c "import sys,json; print(json.load(sys.stdin).get('pid') or '')" 2>/dev/null)
if [[ -z "$pid" ]]; then
  nautilus --new-window & disown
  exit 0
fi
cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || cwd="$HOME"
if [[ -d "$cwd" ]]; then
  nautilus --new-window "$cwd" & disown
else
  nautilus --new-window & disown
fi
