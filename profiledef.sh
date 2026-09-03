#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="pyramid-os"
iso_label="PYRAMID_OS"
iso_publisher="Pyramid OS"
iso_application="Pyramid OS"
iso_version="1.0.0"
install_dir="pyramid"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlz4hc,12')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--long' '-19')
file_permissions=(
  ["/root"]="0:0:750"
)
