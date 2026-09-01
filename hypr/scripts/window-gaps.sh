#!/bin/bash
DEFAULT_IN=8
DEFAULT_OUT=16

now=$(hyprctl getoption general:gaps_in -j | jq -r '.int' 2>/dev/null || hyprctl getoption general:gaps_in -j | jq -r '.float')
if [[ $now == "0" ]]; then
  hyprctl keyword general:gaps_in "$DEFAULT_IN" >/dev/null
  hyprctl keyword general:gaps_out "$DEFAULT_OUT" >/dev/null
else
  hyprctl keyword general:gaps_in 0 >/dev/null
  hyprctl keyword general:gaps_out 0 >/dev/null
fi