# 🔺 Pyramid OS

**Arch Linux • Hyprland • QML • Great Sphinx 1.0.0-alpha**

Elegant, Arch-based distribution with Hyprland Wayland compositor, custom QML bar/widgets, and user-choice philosophy. Inspired by Omarchy but sharper focus on visual refinement.

> **Constitution**: Pyramid Gold `#C9A84C` + Dark `#1A1A1A` + Accent `#D4AF37` • JetBrains Mono + Inter • Papirus Dark • No telemetry • No bloatware

![Pyramid OS](https://img.shields.io/badge/Pyramid_OS-1.0.0--alpha-C9A84C?style=for-the-badge)
![Arch](https://img.shields.io/badge/Arch_Linux-Based-1793D1?style=flat-square&logo=arch-linux)
![Hyprland](https://img.shields.io/badge/Hyprland-0.47+-00D1FF?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## 📋 Table of Contents
- [Features](#features)
- [Quick Start](#quick-start)
- [ISO Build](#iso-build)
- [Installed Configs](#installed-configs)
- [Aesthetic](#aesthetic)
- [Architecture](#architecture)
- [Packages](#packages)
- [Constitution](#constitution)
- [Docs](#docs)

---

## ✨ Features

### F1 Boot & Install
- Bootable UEFI ISO (`archiso` + GRUB) — *build via `./build.sh iso`*
- Calamares graphical installer with Pyramid gold theme
- **Minimal vs Recommended toggle** — user deselects EVERY optional package (Law 1)

### F2 Desktop
- **Hyprland 0.47+** + QML bar (`quickshell/bar/shell.qml`) — 5px rounding, Solitude + Pyramid theme
- **Launcher**: Built-in QML launcher (SUPER+SPACE) — no Walker needed
- **SDDM** optional (enabled by default, `sudo systemctl disable sddm` → TTY autologin)
- **Ghostty** default terminal + Kitty fallback, Nautilus file manager

### F3 System
- NetworkManager + nm-applet, Pipewire + WirePlumber, Blueman (bluetooth disabled by default)
- pacman + chaotic-aur (optional, disabled by default)
- TTY autologin on `tty1` as `pyramid` (if SDDM disabled) → `.zshrc` auto-launches Hyprland

### F4 Visual
- Pyramid gold GRUB theme (`/boot/grub/themes/pyramid/`)
- Plymouth minimal spinner (`plymouth/pyramid-theme/`)
- 5 pyramid wallpapers (`airootfs/usr/share/backgrounds/pyramid/` + `scripts/fetch-wallpapers.sh`)
- Hyprland gaps `2/4` + rounding `5` + blur

**Non-Features (you add them)**: Office suite, dev tools beyond git/base-devel, gaming, virtualization, audio production.

---

## 🚀 Quick Start

### Try the configs on your current Arch

```bash
git clone https://github.com/SulphArk/Pyramid-OS-.git
cd Pyramid-OS-/Pyramid_OS_Code  # or wherever you cloned this repo; this folder IS the distro source

# Copy configs to your home (backups existing)
cp -r airootfs/etc/skel/.config/hypr ~/.config/
cp -r airootfs/etc/skel/.config/quickshell ~/.config/
cp airootfs/etc/skel/.config/ghostty/config ~/.config/ghostty/config
cp airootfs/etc/skel/.zshrc ~/

# Start bar (autostart is in hyprland.lua: hl.dsp.exec_cmd("quickshell -c bar"))
quickshell -c bar
hyprctl reload
```

### Keybinds

| Key | Action |
|-----|--------|
| `SUPER + RETURN` | Terminal (kitty/ghostty) |
| `SUPER + SHIFT + RETURN` | Browser (helium) |
| `SUPER + SPACE` | Launcher (QML) |
| `SUPER + SHIFT + SPACE` | Toggle bar |
| `SUPER + Q` / `W` | Close window |
| `SUPER + T` | Toggle float |
| `SUPER + F` | Fullscreen |
| `SUPER + J` | Toggle split |
| `SUPER + 1..9` | Workspace 1..9 |
| `SUPER + SHIFT + 1..9` | Move window to workspace |
| `SUPER + TAB` | Next workspace |
| `ALT + TAB` | Cycle windows |
| `SUPER + mouse:272/273` | Drag / Resize |

Bar scroll: **Time** = volume ±5% • **Wifi/Bt** = toggle • **Sun** = brightness ±5%

---

## 🏗️ ISO Build

### Prerequisites (Arch)

```bash
sudo pacman -S archiso qemu-system-x86 edk2-ovmf
```

### Build

```bash
# From repo root (Pyramid_OS_Code/)
./build.sh clean   # rm -rf work/ out/
./build.sh iso     # sudo mkarchiso -v -w work -o out .  (+ sha256/md5)
./build.sh test    # qemu -cdrom out/*.iso -m 4G -enable-kvm
./build.sh all     # clean + iso + checksums
./build.sh release # clean + iso + checksums — ready to ship
```

Output: `out/pyramid-os-1.0.0-x86_64.iso` + `.sha256` + `.md5`

### Write to USB

```bash
lsblk -d -o NAME,SIZE,MODEL
sudo dd if=out/pyramid-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### Test matrix (from .context.md)

- `qemu-system-x86_64 -cdrom out/*.iso -m 4G -enable-kvm -smp 4`
- USB on Lenovo V14 IIL ✅ + external laptop
- Targets: ISO <2.5GB, idle RAM <1.2GB, installer <10 min

---

## 📂 Installed Configs

After install, your `~/.config/` mirrors `airootfs/etc/skel/.config/`:

```
~/.config/
├── hypr/
│   ├── hyprland.lua          # gaps 2/4, rounding 5, border pyramid gold, animations
│   ├── hyprpaper.conf
│   └── scripts/              # 14 helpers (bar-toggle, screenshot, window-*, etc.)
├── quickshell/bar/shell.qml  # Top bar: launcher | time+cal | wifi | bt | bri | notif
├── ghostty/config            # Pyramid Gold palette + JetBrains Mono Nerd Font
└── .zshrc                    # pyramid prompt ▲ + TTY autologin hook
```

`/etc/sddm.conf.d/pyramid.conf` + `getty@tty1.service.d/autologin.conf` handle **Choice at Login** (Law 2).

---

## 🎨 Aesthetic

**Pyramid Gold** `#C9A84C` — primary brand • **Dark** `#1A1A1A` • **Accent** `#D4AF37` (used in GRUB, SDDM, Ghostty, Calamares)

- Font: **JetBrains Mono Nerd Font** (terminal) + **Inter** (UI)
- Icons: **Papirus** dark variant
- Bar: Solitude `#171922` `#242838` `#2a2f42` with 5px rounding everywhere (consistent with Hyprland)
- Future: bar palette migration to pure pyramid gold is a 4-line change in `shell.qml` (`bg`, `bgLight`, `fg`, `accent`)

---

## 🏗️ Architecture

```
UEFI/BIOS → GRUB (pyramid theme) → linux-lts + initramfs → systemd
                                              ├─→ SDDM (if enabled) → Hyprland → QML Bar
                                              └─→ TTY1 autologin (pyramid) → .zshrc exec Hyprland
```

**Package Groups** (Law 5: Base → Core → Apex)

- `pyramid-base` (`packages.x86_64`): ~200 pkgs, always installed
- `pyramid-recommended` (`packages.recommended.x86_64`): browsers, media, bluetooth, cups — *Calamares toggle OFF by default*
- `pyramid-dev` (`packages.dev.x86_64`): node, go, rust, docker, postgres — *user adds later*

Runtime services|default|toggle
---|---|---
NetworkManager|enabled|`systemctl`
pipewire|enabled|user service
bluetooth|disabled|`systemctl enable bluetooth`
cups|disabled|`systemctl enable cups`
sddm|enabled|`systemctl disable sddm` → TTY

See `.context.md` § Architecture for full `/` tree.

---

## 📦 Packages

- **Base** (`packages.x86_64`): base, base-devel, linux-lts (+headers), systemd, grub, efibootmgr, mkinitcpio, mesa, vulkan-intel, hyprland, wayland, xorg-xwayland, sddm, pipewire (+pulse/alsa/jack), wireplumber, networkmanager (+applet), ghostty, kitty, nautilus, wofi/waybar fallbacks, git/sudo/vim/nvim/micro/htop/btop, ttf-jetbrains-mono-nerd + inter + noto, papirus, calamares, zsh, python/pip, xdg portals, hyprpaper/hyprlock, grim/slurp, etc. — *pinned in file, reproducible*.
- **Recommended** (`packages.recommended.x86_64`): firefox(+ublock), chromium, imv/zathura/mpv, bluez, cups/hplip, gimp/inkscape, etc. — *user opts in*.

Chaotic-AUR and multilib are **commented** in `pacman.conf` — uncomment only if user wants.

---

## 🔒 Constitution (summary)

**Laws — never break:**
1. User Sovereignty — no forced installs, no telemetry, no bloat
2. Choice at Login — SDDM optional, TTY works, Hyprland default / Sway fallback
3. Aesthetic Consistency — gold/dark/accent, JetBrains+Inter, Papirus dark
4. Build Reproducibility — same ISO every build, no internet during install
5. Pyramid Philosophy — Base stable boring, Core beautiful functional, Apex extensible
6. Pyramid OS contribution guide - see CONTRIBUTING.md

**Hierarchy**: User > Constitution; Security > Convenience; Aesthetics > Features; Lean > Bloated.

**Forbidden**: Snap, Flatpak, GNOME Software, KDE Discover, Timeshift, Docker (heavy), X11.

Full text: `.context.md` (§ Constitution) + `AGENT.md`

---

## 📚 Docs

- `.context.md` — single source of truth (852 lines: Constitution, PRD, Tech Stack, Tasks, Packages, Build/Installer scripts, FAQ)
- `AGENT.md` — AI worker instructions
- `docs/ARCHITECTURE.md` — deep drive on boot, dir tree, services
- `docs/INSTALL.md` — bare-metal install walkthrough + troubleshooting
- `scripts/install.sh` — emergency CLI installer (when Calamares fails)
- `scripts/fetch-wallpapers.sh` — fetches 5 pyramid wallpapers

---

## 🔑 Quick Commands Reference (from .context.md)

```bash
sudo pacman -S archiso
./build.sh iso
qemu-system-x86_64 -cdrom out/*.iso -m 4G -enable-kvm -smp 4
sudo dd if=out/pyramid-os-*.iso of=/dev/sdX bs=4M status=progress
sudo systemctl enable sddm   # login screen
sudo systemctl disable sddm  # TTY autologin
sha256sum out/*.iso > out/pyramid-os.iso.sha256
./build.sh release  # all + checksums ready to ship
```

---

## 🤝 Contributing

PRs welcome. Keep Law 1-6. Run `shellcheck` on `build.sh`/`customize_airootfs.sh` before commit.

---

## 📝 License

MIT — see `LICENSE`

---

**Pyramid OS — Arch Linux, styled your way.** *Great Sphinx 1.0.0-alpha*
