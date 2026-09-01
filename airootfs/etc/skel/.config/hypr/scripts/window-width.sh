#!/bin/bash
set -euo pipefail

STATE_DIR="$HOME/.local/state/hypr/windows"

active_window() { hyprctl activewindow -j 2>/dev/null; }
window_key() { jq -r '[.class, .initialClass, .title] | map(select(. != null and . != "")) | first // empty' <<<"$1"; }
workspace_key() { jq -r '.workspace.id // .workspace.name // empty' <<<"$1"; }

state_file_for() {
  local key="$1" workspace="$2"
  local filename="workspace-${workspace}-${key}"
  filename="${filename//\//_}"
  printf '%s/%s.width' "$STATE_DIR" "$filename"
}

hypr_dispatch() {
  local lua="$1"
  shift
  hyprctl dispatch "$lua" >/dev/null 2>&1 || hyprctl dispatch "$@" >/dev/null
}

window_width() {
  hyprctl clients -j | jq -er --arg address "$1" '.[] | select(.address == $address) | .size[0]'
}

resize_width_by() {
  hypr_dispatch "hl.dsp.window.resize({ window = \"$1\", x = $2, y = 0, relative = true })" resizeactive "$2" 0 "$1"
}

save_width() {
  local active="$1" key="$2" workspace="$3" state_file="$4"
  local width tmp
  width=$(jq -er '.size[0]' <<<"$active")
  mkdir -p "$STATE_DIR"
  tmp=$(mktemp "$STATE_DIR/.width.XXXXXX")
  printf '%s\n' "$width" >"$tmp"
  mv "$tmp" "$state_file"
  notify-send "Saved width for $key on workspace $workspace" -u low
}

restore_width() {
  local active="$1" key="$2" workspace="$3" state_file="$4"
  local address current_width delta direction next_width probe probe_delta width window
  if [[ ! -f $state_file ]]; then
    notify-send "No saved width for $key on workspace $workspace" "Use Super + Alt + Home to save one." -u low
    exit 1
  fi
  width=$(<"$state_file")
  [[ $width =~ ^[0-9]+$ ]] || exit 1
  address=$(jq -r '.address // empty' <<<"$active")
  [[ -n $address ]] || exit 1
  window="address:$address"
  current_width=$(window_width "$address")
  ((current_width == width)) && exit 0
  for probe in 10 -10; do
    resize_width_by "$window" "$probe"
    next_width=$(window_width "$address")
    if ((next_width != current_width)); then
      direction=$(( (next_width - current_width) * probe > 0 ? 1 : -1 ))
      current_width=$next_width
      break
    fi
  done
  [[ -n $direction ]] || exit 1
  for _ in {1..6}; do
    delta=$((width - current_width))
    ((delta == 0)) && break
    probe_delta=$((delta * direction))
    resize_width_by "$window" "$probe_delta"
    next_width=$(window_width "$address")
    ((next_width == current_width)) && break
    current_width=$next_width
  done
}

action=${1:-}
[[ $action == "save" || $action == "restore" ]] || { echo "usage: window-width.sh save|restore" >&2; exit 1; }

active=$(active_window)
key=$(window_key "$active"); [[ -n $key ]] || exit 1
workspace=$(workspace_key "$active"); [[ -n $workspace ]] || exit 1
state_file=$(state_file_for "$key" "$workspace")

case "$action" in
  save) save_width "$active" "$key" "$workspace" "$state_file" ;;
  restore) restore_width "$active" "$key" "$workspace" "$state_file" ;;
esac