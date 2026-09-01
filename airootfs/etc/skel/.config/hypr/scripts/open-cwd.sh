#!/bin/bash
pid=$(hyprctl activewindow -j | jq -r '.pid // empty')
if [[ -z $pid ]]; then
  nautilus
  exit 0
fi
cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || cwd=$HOME
nautilus "$cwd"