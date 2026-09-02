#!/bin/bash
# Parse .desktop files into compact JSON for quickshell launcher
# Resolves icon names to full file paths for proper icon display

DIRS="/usr/share/applications /usr/local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/applications"
ICON_ROOTS="$HOME/.local/share/icons /usr/share/icons"
SIZES="24x24 32x32 48x48 scalable"

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

resolve_icon() {
    local name="$1"
    [ -z "$name" ] && return
    case "$name" in
        /*|./*) printf '%s' "$name"; return ;;
    esac
    for root in $ICON_ROOTS; do
        [ -d "$root" ] || continue
        # Search inside each theme dir (Papirus, hicolor, etc.)
        for themedir in "$root"/*/; do
            [ -d "$themedir" ] || continue
            for sz in $SIZES; do
                for ext in svg png; do
                    local f="${themedir}${sz}/apps/${name}.${ext}"
                    [ -f "$f" ] && { printf '%s' "$f"; return; }
                done
            done
        done
        # Direct fallback (some setups have icons directly under root)
        for sz in $SIZES; do
            for ext in svg png; do
                local f="${root}/${sz}/apps/${name}.${ext}"
                [ -f "$f" ] && { printf '%s' "$f"; return; }
            done
        done
    done
    printf '%s' "$name"
}

printf '['
first=1
for dir in $DIRS; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue
        case "$f" in *mimeinfo.cache) continue;; esac

        in_section=0
        name="" genericname="" comment="" icon="" exec="" nodisplay=""

        while IFS= read -r line; do
            case "$line" in
                "[Desktop Entry]") in_section=1 ;;
                \[*) in_section=0 ;;
            esac
            if [ $in_section -eq 1 ]; then
                case "$line" in
                    Name=*)       name="${line#Name=}" ;;
                    GenericName=*) genericname="${line#GenericName=}" ;;
                    Comment=*)    comment="${line#Comment=}" ;;
                    Icon=*)       icon="${line#Icon=}" ;;
                    Exec=*)       exec="${line#Exec=}" ;;
                    NoDisplay=true) nodisplay="true" ;;
                esac
            fi
        done < "$f"

        [ -z "$name" ] && continue
        [ "$nodisplay" = "true" ] && continue

        resolved_icon=$(resolve_icon "$icon")

        [ $first -eq 1 ] && first=0 || printf ','
        id=$(basename "$f" .desktop)
        printf '{"id":"%s","name":"%s","genericName":"%s","comment":"%s","icon":"%s","exec":"%s","noDisplay":false}' \
            "$(json_escape "$id")" \
            "$(json_escape "$name")" \
            "$(json_escape "$genericname")" \
            "$(json_escape "$comment")" \
            "$(json_escape "$resolved_icon")" \
            "$(json_escape "$exec")"
    done
done
printf ']'
