#!/bin/bash
ACTIVE_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')
[[ $ACTIVE_WORKSPACE =~ ^-?[0-9]+$ ]] || exit 1
CURRENT_LAYOUT=$(hyprctl activeworkspace -j | jq -r '.tiledLayout')

case "$CURRENT_LAYOUT" in
  dwindle) NEW_LAYOUT=scrolling ;;
  *) NEW_LAYOUT=dwindle ;;
esac

hyprctl eval "hl.workspace_rule({ workspace = \"$ACTIVE_WORKSPACE\", layout = \"$NEW_LAYOUT\" })" >/dev/null 2>&1 || \
  hyprctl keyword workspace "$ACTIVE_WORKSPACE, layout:$NEW_LAYOUT"
notify-send "Workspace layout set to $NEW_LAYOUT" -u low