#!/usr/bin/env bash
Pyramid OS Master Build Script
# Pyramid OS 1.0.0-alpha "Great Sphinx" | Arch Linux + Hyprland + QML
# Usage: ./build.sh [clean|iso|test|release|help]
# Law 4: Build Reproducibility | Law 6: AUDITABLE + BULLETPROOF

set -euo pipefail
IFS=$'\n\t'

# ── paths (repo-root aware) ────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
# For legacy support: if user runs from ~/pyramid-os, still work
if [[ "$PROJECT_DIR" == *"Pyramid_OS_Code" ]]; then
  ISO_SRC="$PROJECT_DIR"
else
  ISO_SRC="$PROJECT_DIR"
fi
OUT_DIR="$PROJECT_DIR/out"
WORK_DIR="$PROJECT_DIR/work"

# ── colors ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[0;90m'
NC='\033[0m'

log()  { echo -e "${GREEN}▲${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✖${NC} $*" >&2; }
info() { echo -e "${DIM}  $*${NC}"; }

# ── checks ─────────────────────────────────────────────────
require_root_for_iso() {
  if [[ $EUID -ne 0 ]]; then
    err "mkarchiso needs root. Re-running with sudo..."
    exec sudo -- "$0" "$@"
  fi
}

check_deps() {
  local missing=()
  for c in mkarchiso; do
    command -v "$c" &>/dev/null || missing+=("$c")
  done
  if (( ${#missing[@]} )); then
    err "Missing: ${missing[*]}"
    info "Install: sudo pacman -S archiso"
    exit 1
  fi
}

# ── functions ──────────────────────────────────────────────
clean() {
  log "Cleaning build artifacts..."
  # Only remove work/out that we own
  rm -rf "$OUT_DIR" 2>/dev/null || sudo rm -rf "$OUT_DIR"
  rm -rf "$WORK_DIR" 2>/dev/null || sudo rm -rf "$WORK_DIR"
  mkdir -p "$OUT_DIR" "$WORK_DIR"
  log "Clean complete"
}

sync_airootfs() {
  # Ensure airootfs skel configs are fresh from live user configs (if running on Pyramid dev machine)
  if [[ -d "$HOME/.config/hypr" && -d "$PROJECT_DIR/airootfs/etc/skel/.config/hypr" ]]; then
    info "Syncing live hypr/quickshell configs → airootfs/skel (if newer)..."
    # Only copy if live is newer than repo; non-destructive
    # Uncomment to auto-sync on every build:
    # cp -u "$HOME/.config/hypr/hyprland.lua" "$PROJECT_DIR/airootfs/etc/skel/.config/hypr/" 2>/dev/null || true
    # cp -u "$HOME/.config/quickshell/bar/shell.qml" "$PROJECT_DIR/airootfs/etc/skel/.config/quickshell/bar/" 2>/dev/null || true
  fi
}

build_iso() {
  log "Building ISO..."
  check_deps
  sync_airootfs
  mkdir -p "$OUT_DIR" "$WORK_DIR"

  # archiso expects profiledef.sh + pacman.conf + packages.x86_64 in ISO_SRC
  # Our repo already has them at top-level; mkarchiso will use them
  # We run from PROJECT_DIR so mkarchiso finds them
  cd "$PROJECT_DIR"
  # shellcheck disable=SC2068
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" .

  local iso
  iso=$(ls -1t "$OUT_DIR"/*.iso 2>/dev/null | head -1 || true)
  if [[ -n "$iso" ]]; then
    log "ISO built: $iso"
    ls -lh "$iso"
  else
    err "No ISO produced. Check $WORK_DIR/logs"
    exit 1
  fi
}

test_qemu() {
  local iso
  iso=$(ls -1t "$OUT_DIR"/*.iso 2>/dev/null | head -1 || true)
  if [[ -z "$iso" ]]; then
    err "No ISO in $OUT_DIR. Run ./build.sh iso first."
    exit 1
  fi
  log "Testing $iso in QEMU (4G, KVM if available)..."
  local kvm=""
  [[ -c /dev/kvm ]] && kvm="-enable-kvm -cpu host" || kvm="-cpu qemu64"
  # shellcheck disable=SC2086
  qemu-system-x86_64 \
    -cdrom "$iso" \
    -m 4096 \
    -smp 4 \
    $kvm \
    -machine q35 \
    -vga virtio \
    -display gtk,gl=on \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -boot d
}

create_checksums() {
  local iso
  iso=$(ls -1t "$OUT_DIR"/*.iso 2>/dev/null | head -1 || true)
  if [[ -z "$iso" ]]; then
    err "No ISO to checksum"
    exit 1
  fi
  log "Creating checksums..."
  cd "$OUT_DIR"
  sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256"
  md5sum "$(basename "$iso")" > "$(basename "$iso").md5"
  cat "$(basename "$iso").sha256"
  cat "$(basename "$iso").md5"
  log "Checksums created"
}

# ── main ───────────────────────────────────────────────────
case "${1:-help}" in
  clean)
    clean
    ;;
  iso)
    # mkarchiso needs root; re-exec with sudo if needed
    if [[ $EUID -ne 0 ]]; then exec sudo -- "$0" iso; fi
    build_iso
    create_checksums
    ;;
  test)
    test_qemu
    ;;
  all)
    clean
    if [[ $EUID -ne 0 ]]; then exec sudo -- "$0" all; fi
    build_iso
    create_checksums
    log "Ready to test: ./build.sh test"
    ;;
  release)
    clean
    if [[ $EUID -ne 0 ]]; then exec sudo -- "$0" release; fi
    build_iso
    create_checksums
    log "Release build complete!"
    info "ISO: $OUT_DIR/"
    ls -lh "$OUT_DIR"
    ;;
  help|*)
    echo -e "${CYAN}🔺 Pyramid OS - Build System${NC}  (Great Sphinx 1.0.0-alpha)"
    echo ""
    echo -e "${GREEN}Usage:${NC} $0 [command]"
    echo ""
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${YELLOW}clean${NC}     Remove work/ and out/"
    echo -e "  ${YELLOW}iso${NC}       Build the ISO (needs sudo)"
    echo -e "  ${YELLOW}test${NC}      Boot ISO in QEMU"
    echo -e "  ${YELLOW}all${NC}       Clean + Build + Checksums"
    echo -e "  ${YELLOW}release${NC}   Clean + Build + Checksums + Ready to ship"
    echo ""
    echo -e "${DIM}Profile: $PROJECT_DIR/profiledef.sh"
    echo -e "Output:  $OUT_DIR/${NC}"
    echo ""
    echo -e "${DIM}Constitution: Law 4 reproducible, Law 1 user choice, Law 3 pyramid gold #C9A84C${NC}"
    ;;
esac
