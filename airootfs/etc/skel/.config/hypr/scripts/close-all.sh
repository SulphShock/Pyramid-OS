#!/bin/bash
hyprctl clients -j | jq -r '.[].address' | while read -r addr; do
  hyprctl dispatch closewindow "address:$addr" >/dev/null
done
hyprctl dispatch workspace 1