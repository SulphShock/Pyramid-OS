#!/usr/bin/env bash
Pyramid OS customize_airootfs.sh
# Executed inside the new ISO's airootfs during mkarchiso (as root in chroot)
# Law 2: Choice at Login | Law 5: Pyramid philosophy | Law 6: BULLETPROOF + AUDITABLE

set -euo pipefail

echo "▲ Pyramid OS - customizing airootfs..."

# ── locale & time ──────────────────────────────────────────
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || true
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "pyramid" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1   localhost
::1        localhost
127.0.1.1   pyramid.localdomain pyramid
EOF

# ── live user: pyramid (password: pyramid, also live ISO user) ──
# Calamares will replace this with the real user on install; this is only for live session
if ! id pyramid &>/dev/null; then
  useradd -m -G wheel,audio,video,optical,storage,network,power -s /bin/zsh pyramid
  echo "pyramid:pyramid" | chpasswd
  echo "root:root" | chpasswd
fi
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-pyramid-live
chmod 440 /etc/sudoers.d/10-pyramid-live

# ── skeleton: copy skel to live user if empty ──────────────
if [[ -d /etc/skel/.config ]]; then
  cp -a /etc/skel/. /home/pyramid/ 2>/dev/null || true
  chown -R pyramid:pyramid /home/pyramid
fi

# ── services: Law 2 & Runtime Services table ───────────────
# Enabled by default: NetworkManager, sddm (toggleable), pipewire is user service
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true
# TTY autologin is via drop-in, but only effective when sddm disabled; keep enabled
# Bluetooth & CUPS disabled by default (Law 1)
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable cups.service 2>/dev/null || true

# ── permissions for Hyprland scripts ───────────────────────
chmod +x /home/pyramid/.config/hypr/scripts/*.sh 2>/dev/null || true
chmod +x /etc/skel/.config/hypr/scripts/*.sh 2>/dev/null || true

# ── SDDM theme assets ──────────────────────────────────────
# If pyramid SDDM theme not present, fallback to maldives/breeze
if [[ ! -d /usr/share/sddm/themes/pyramid ]]; then
  echo "WARN: SDDM pyramid theme missing, using breeze fallback" >&2
  mkdir -p /usr/share/sddm/themes/pyramid 2>/dev/null || true
fi

# ── pacman: initialize keyring for live session ────────────
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux 2>/dev/null || true

# ── reflector: rank mirrors (fast) ─────────────────────────
if command -v reflector &>/dev/null; then
  reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
fi

# ── font cache ─────────────────────────────────────────────
fc-cache -f 2>/dev/null || true

echo "✓ Pyramid airootfs customized"
