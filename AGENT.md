# Pyramid OS — Contributor Guide

Conventions, project state, and decision rules for anyone working on Pyramid OS.

## Project State

- Arch installed on Lenovo V14 IIL (reference hardware)
- Hyprland config done (`hypr/hyprland.lua` + `airootfs/etc/skel/.config/hypr/`)
- QML bar/widgets done (`quickshell/bar/shell.qml`)
- ISO build system scaffolded (`profiledef.sh`, `packages.*`, `build.sh`)
- Calamares installer theme (pyramid branding ready)
- GRUB/Plymouth theme ready (`grub/theme.txt`)
- Awaiting: QEMU/USB testing, release (checksums, ISO upload)

## Design Constitution

1. **User Sovereignty**: no forced installs, no telemetry, no bloatware
2. **Choice at Login**: SDDM optional, TTY autologin must work, Hyprland default / Sway fallback
3. **Aesthetic**: Pyramid Gold `#C9A84C` + Dark `#1A1A1A` + Accent `#D4AF37`, JetBrains Mono + Inter, Papirus dark
4. **Reproducibility**: pinned packages, no internet during install, same ISO every build
5. **Pyramid Philosophy**: Base (stable) → Core (beautiful) → Apex (extensible)

## Decision Hierarchy

1. User preference > Constitution
2. Security > Convenience
3. Aesthetics > Features
4. Lean base > Bloated full install

## Forbidden Technologies

Snap, Flatpak, GNOME Software, KDE Discover, Timeshift, Docker (heavy, user installs if needed), X11.

## Tooling Notes

- Environment: Arch Linux on Lenovo V14 IIL
- Target: bootable ISO with Calamares installer at `out/pyramid-os-1.0.0-x86_64.iso`
- Editors: any

## Directives

1. **BULLETPROOF**: every script has `set -euo pipefail` + error handling
2. **AUDITABLE**: every file has a comment header explaining its purpose
3. **REPRODUCIBLE**: pin versions where possible
4. **DUAL-MODE**: support both SDDM and TTY login
5. **USER CHOICE**: minimal base + optional recommended group
6. **BRANDING**: everything says "Pyramid OS 1.0.0 - Great Sphinx"

## Workflow (Contributing)

1. Skim `docs/ARCHITECTURE.md` to understand the layout
2. Make the change in the right tree (`airootfs/` for shipped config, root for build/profile)
3. Test in QEMU (`./build.sh test`) before opening a PR
4. Update `README.md` / `docs/` if the user-facing surface changed
5. Stage (`git add`) and commit with a descriptive message

## File Map

- `profiledef.sh` + `pacman.conf` + `packages.x86_64` → archiso profile
- `airootfs/` → overlay copied into ISO root (skel → `/home/pyramid`)
- `airootfs/root/customize_airootfs.sh` → chroot setup (user, services, locale)
- `build.sh` → master build (`clean`/`iso`/`test`/`all`/`release`)
- `scripts/install.sh` → emergency CLI installer
- `grub/theme.txt` → shared GRUB theme
- `calamares/branding/pyramid/` → installer branding

## Constraints

- ISO <2.5GB, idle RAM <1.2GB, base 200–300 packages, kernel `linux-lts`
- Never add Snap/Flatpak without explicit user override

## Quick Commands

```bash
sudo pacman -S archiso
./build.sh iso        # needs sudo, builds out/*.iso
./build.sh test       # QEMU 4G
sudo dd if=out/*.iso of=/dev/sdX bs=4M status=progress
sudo systemctl enable sddm    # login screen
sudo systemctl disable sddm   # TTY autologin
```
