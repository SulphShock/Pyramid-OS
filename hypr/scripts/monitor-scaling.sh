#!/bin/bash
SCALES=(1 1.25 1.6 2 3 4)

hypr_dispatch() {
  hyprctl eval "$1" >/dev/null 2>&1
}

clean_scale() {
  awk -v scale="$1" -v width="$2" -v height="$3" '
    function gcd(a, b, t) { while (b) { t = a % b; a = b; b = t } return a }
    BEGIN {
      g = gcd(width * 120, height * 120)
      k = int(scale * 120 + 0.5)
      if (k > g) k = g
      while (g % k != 0) k++
      printf "%g\n", k / 120
    }'
}

set_scale() {
  local requested="$1"
  local info
  info=$(hyprctl monitors -j | jq -e -c '.[] | select(.focused == true)')
  local name width height rate scale
  name=$(echo "$info" | jq -r '.name')
  width=$(echo "$info" | jq -r '.width')
  height=$(echo "$info" | jq -r '.height')
  rate=$(echo "$info" | jq -r '.refreshRate')
  scale=$(clean_scale "$requested" "$width" "$height")
  hypr_dispatch "hl.monitor({ output = \"$name\", mode = \"${width}x${height}@${rate}\", position = \"auto\", scale = $scale })"
}

step() {
  local direction="$1"
  local info scale
  info=$(hyprctl monitors -j | jq -e -c '.[] | select(.focused == true)')
  scale=$(echo "$info" | jq -r '.scale')
  local width height
  width=$(echo "$info" | jq -r '.width')
  height=$(echo "$info" | jq -r '.height')

  # Filter presets to those valid for this monitor's resolution.
  local valid=() s
  for s in "${SCALES[@]}"; do
    if awk -v scale="$s" -v w="$width" -v h="$height" '
        function gcd(a,b,t){while(b){t=a%b;a=b;b=t}return a}
        BEGIN { g=gcd(w*120,h*120); k=int(scale*120+.5); if(k>g)k=g; exit !(g%k==0 && k<=g) }'; then
      valid+=("$s")
    fi
  done

  local i current
  current=$(awk -v s="$scale" -v list="${valid[*]}" 'BEGIN { n=split(list,a," "); for(i=1;i<=n;i++){ d=a[i]-s; if(d<0)d=-d; if(d<bestd || bestd==""){bestd=d; best=i} } print best }')
  current="${current:-1}"
  if [[ $direction == "up" ]]; then
    [[ $current -lt ${#valid[@]} ]] && set_scale "${valid[$current]}"
  else
    [[ $current -gt 1 ]] && set_scale "${valid[$((current - 1))]}"
  fi
}

case "${1:-}" in
  up) step up ;;
  down) step down ;;
  *) echo "usage: monitor-scaling.sh up|down" >&2; exit 1 ;;
esac