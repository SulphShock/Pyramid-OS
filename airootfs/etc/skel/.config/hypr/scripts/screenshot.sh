#!/bin/bash
OUTPUT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
MODE="${1:-fullscreen}"

mkdir -p "$OUTPUT_DIR"
FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

case "$MODE" in
  region)
    SELECTION=$(slurp -b 00000080 2>/dev/null) || exit 0
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    ;;
  *)
    grim -o "$(hyprctl activeworkspace -j | jq -r '.monitor')" "$FILEPATH" || exit 1
    ;;
esac

wl-copy --type image/png <"$FILEPATH"
notify-send "Screenshot saved" "$FILEPATH" -i "$FILEPATH" -u low