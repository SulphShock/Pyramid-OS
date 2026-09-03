#!/usr/bin/env bash
# Pyramid wallpaper fetcher
# Downloads 5 curated wallpapers to airootfs/usr/share/backgrounds/pyramid
set -euo pipefail
DEST="${1:-$(dirname "$0")/../airootfs/usr/share/backgrounds/pyramid}"
mkdir -p "$DEST"
echo "▲ Pyramid OS - fetching wallpapers to $DEST"
urls=(
  "https://picsum.photos/seed/pyramid1/3840/2160"
  "https://picsum.photos/seed/pyramid2/3840/2160"
  "https://picsum.photos/seed/pyramid3/3840/2160"
  "https://picsum.photos/seed/pyramid4/3840/2160"
  "https://picsum.photos/seed/pyramid5/3840/2160"
)
for i in "${!urls[@]}"; do
  n=$((i+1))
  out="$DEST/pyramid-0${n}.jpg"
  if [[ -f "$out" ]]; then echo "• $out exists, skip"; continue; fi
  echo "↓ $out"
  curl -fsSL "${urls[i]}" -o "$out" || echo "WARN: failed $out"
done
echo "✓ done"
