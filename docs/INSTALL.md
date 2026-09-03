Pyramid OS Install Guide

## Live ISO

1. **Boot** USB → GRUB "Pyramid OS 1.0.0" → auto-login as `pyramid` (pass `pyramid`) → Hyprland + QML bar
2. **Check**: `quickshell -c bar` should be running (`pgrep quickshell`), bar visible at top (5px gaps/rounding)
3. **Installer**: Launch Calamares from desktop or `sudo calamares`
   - Choose **Minimal** (default, Law 1) or **Recommended** (adds firefox, imv, bluez, cups, gimp...)
   - Partition: Guided LVM+ext4 or Manual (fdisk/cfdisk)
   - User: your username/hostname; Calamares copies `/etc/skel` → `/home/<you>`
4. **Reboot**: Remove USB → SDDM login (gold pyramid theme) or TTY if you disabled SDDM

## Emergency CLI (Calamares fails)

```bash
sudo /root/pyramid-configs/scripts/install.sh  # or scripts/install.sh inside live ISO
# Follow prompts: disk /dev/sda, hostname, username, password
```

## Post-Install

```bash
# Toggle login mode
sudo systemctl disable sddm  # → TTY autologin on tty1 ( .zshrc launches Hyprland)
sudo systemctl enable sddm   # → graphical login

# Enable optional services (disabled by default, Law 1)
sudo systemctl enable --now bluetooth
sudo systemctl enable --now cups

# Update
sudo pacman -Syu
yay -S chaotic-aur-keyring  # if you uncommented chaotic-aur in /etc/pacman.conf

# Bar controls
# SUPER+SPACE launcher, SUPER+RETURN terminal, click time→calendar, wifi/bt/bri panels, bell→notifications
# Scroll: time=volume, wifi=toggle, bt=toggle, sun=brightness

# Theming
# Hyprland border: airootfs/etc/skel/.config/hypr/hyprland.lua  col.active_border
# Bar palette: quickshell/bar/shell.qml  readonly property color bg/accent
# GRUB: /boot/grub/themes/pyramid/theme.txt  (also /usr/share/grub/themes/pyramid/)
# Ghostty: ~/.config/ghostty/config
```

## Troubleshooting

- **Hyprland lua errors on boot** (seen in `hyprland` log: `bezier or spring is required`): fixed in this repo — `hl.animation({ leaf, bezier="default" })` + removed `popups` leaf.
- **Bar not visible**: `killall quickshell; quickshell -c bar &` and check `~/.config/quickshell/bar/shell.qml` → `hyprctl reload` if you changed `hyprland.lua`.
- **SDDM black screen**: `sudo systemctl status sddm`, check `/etc/sddm.conf.d/pyramid.conf` theme exists, fallback to `breeze`.
- **No wifi**: `nm-applet` + `nm-connection-editor` in base; `nmtui` in terminal.
- **ISO too big >2.5GB**: Remove `packages.dev` from build, check `out/` and `work/` not included, use `build.sh clean`.

## Hardware

Tested: **Lenovo V14 IIL** ✅ (Intel integrated, mesa+vulkan-intel). NVIDIA needs `nvidia-dkms` + `env = WLR_NO_HARDWARE_CURSORS,1` in `hyprland.lua`.

## Checksums

```bash
sha256sum -c out/*.sha256
md5sum -c out/*.md5
```
