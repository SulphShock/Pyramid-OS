#!/bin/bash
width=${1:-1300}
height=${2:-900}

active=$(hyprctl activewindow -j)
pinned=$(echo "$active" | jq ".pinned")
addr=$(echo "$active" | jq -r ".address")
window="address:$addr"

hypr_dispatch() {
  local lua="$1"
  shift
  hyprctl dispatch "$lua" >/dev/null 2>&1 || hyprctl dispatch "$@" >/dev/null
}

if [[ $pinned == "true" ]]; then
  hypr_dispatch "hl.dsp.window.pin({ window = \"$window\" })" pin "$window"
  hypr_dispatch "hl.dsp.window.float({ window = \"$window\", action = \"toggle\" })" togglefloating "$window"
  hypr_dispatch "hl.dsp.window.tag({ window = \"$window\", tag = \"-pop\" })" tagwindow -pop "$window"
elif [[ -n $addr ]]; then
  hypr_dispatch "hl.dsp.window.float({ window = \"$window\", action = \"toggle\" })" togglefloating "$window"
  hypr_dispatch "hl.dsp.window.resize({ window = \"$window\", x = $width, y = $height })" resizeactive exact "$width" "$height" "$window"
  hypr_dispatch "hl.dsp.window.center({ window = \"$window\" })" centerwindow "$window"
  hypr_dispatch "hl.dsp.window.pin({ window = \"$window\" })" pin "$window"
  hypr_dispatch "hl.dsp.window.alter_zorder({ window = \"$window\", mode = \"top\" })" alterzorder top "$window"
  hypr_dispatch "hl.dsp.window.tag({ window = \"$window\", tag = \"+pop\" })" tagwindow +pop "$window"
fi