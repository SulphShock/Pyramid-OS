# 🔺 Pyramid OS

**Arch Linux • Hyprland • Solitude Theme • No Bloat**

A minimal, elegant Arch-based Linux distro with Hyprland, custom QML bar, and the Solitude color palette by HANCORE. You control what installs. Nothing forced.

## Features

- **Hyprland** — Fast Wayland tiling compositor with 5px rounding and minimal aesthetic
- **QML Bar** — Custom top bar (quickshell) showing time, wifi, brightness, volume
- **Solitude Theme** — Curated by HANCORE-linux; minimal, cohesive across terminal, Hyprland, lock screen, and applications
- **User Choice** — Minimal base install. Recommended packages are opt-in.
- **Clean Boot** — GRUB → Arch → Hyprland. No unnecessary services.
- **TTY Option** — SDDM optional. TTY autologin available.

## Quick Start

### Download & Install

```bash
# Download ISO from Releases
# Write to USB:
sudo dd if=pyramid-os-1.0.0-x86_64.iso of=/dev/sdX bs=4M status=progress

# Boot USB, run Calamares installer
# Login as 'pyramid', Hyprland starts automatically
```

### Keybinds

| Shortcut | Action |
| --- | --- |
| `SUPER + RETURN` | Terminal |
| `SUPER + SPACE` | Launcher |
| `SUPER + Q` | Close window |
| `SUPER + T` | Toggle float |
| `SUPER + F` | Fullscreen |
| `SUPER + 1..9` | Switch workspace |

### Bar Controls

- **Scroll on time**: Volume ±5%
- **Scroll on wifi/bt icon**: Toggle connection
- **Scroll on brightness icon**: Adjust brightness ±5%

## Build from Source

```bash
# Prerequisites
sudo pacman -S archiso qemu-system-x86 edk2-ovmf

# Clone & build
git clone https://github.com/SulphShock/Pyramid-OS.git
cd Pyramid-OS
./build.sh clean
./build.sh iso

# Test in VM
./build.sh test

# Output: out/pyramid-os-1.0.0-x86_64.iso
```

## System Specs

- **Base**: Arch Linux, linux-lts kernel
- **WM**: Hyprland 0.47+
- **Terminal**: Ghostty (Kitty fallback)
- **Font**: JetBrains Mono Nerd, Inter
- **Icons**: Papirus Dark
- **Theme**: [Solitude by HANCORE-linux](https://github.com/HANCORE-linux/omarchy-solitude-theme)
- **Colors**: Minimal palette — dark bg `#101315`, foreground `#cacccc`, accent `#798186`

## What's NOT Included

- Snap / Flatpak
- GNOME / KDE / Xfce
- Docker, VirtualBox, gaming packages
- Development tools (install manually via pacman)

Add what you need after install.

## Package Groups

- **Base** (automatic): ~200 essential packages
- **Recommended** (opt-in): Firefox, media players, GIMP, Inkscape
- **Dev** (manual): Node, Rust, Go, Python

## Philosophy

1. **User controls everything** — No forced installs
2. **Consistent design** — One cohesive aesthetic or nothing
3. **Arch stable only** — No experimental branches

## Credits

- **Theme**: Solitude by [HANCORE-linux](https://github.com/HANCORE-linux/omarchy-solitude-theme) (MIT License)
- **Base**: Arch Linux + Hyprland
- **Built by**: SulphShock

## License

MIT — See LICENSE file

---

**Pyramid OS — Arch Linux, styled your way. ISO: 3.1GB. Version: 1.0.0-alpha**
