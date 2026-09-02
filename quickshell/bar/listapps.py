#!/usr/bin/env python3
"""Scan .desktop files and print application entries as tab-separated lines.

Columns emitted per line:
    name<TAB>generic<TAB>icon<TAB>id<TAB>exec

Only Type=Application entries that are not NoDisplay/Hidden are listed.
"""
import os
import glob
import sys
import re

HIDDEN_PATTERNS = [
    r"avahi",
    r"bssh",
    r"bvnc",
    r"xdg-desktop-portal",
    r"org\.freedesktop\.impl\.portal",
    r"system-config-printer",
    r"^nm-connection-editor$",
    r"hardware-monitor",
    r"^org\.gnome\.OnlineAccounts",
    r"^gnome-abrt",
    r"^org\.gnome\.Software\.PackageUpdater",
    r"^cups",
    r"^flutter",
    r"^uxterm",
    r"hplip",
    r"hp-toolbox",
    r"^vino",
    r"^polkit",
    r"^charactermap",
    r"^unicode",
    r"^yelp",          # help viewer
    r"^gnome-language-selector",
    r"^im-config",
    r"^org\.gnome\.FontViewer",
    r"^org\.gnome\.DiskUsage$",
]

def hidden(app_id, exec_s, name):
    hay = (app_id.lower() + " " + exec_s.lower() + " " + name.lower())
    for p in HIDDEN_PATTERNS:
        if re.search(p, hay):
            return True
    return False

data_dirs = []
env_dirs = os.environ.get("XDG_DATA_DIRS", "")
for d in env_dirs.split(":"):
    d = d.strip()
    if d:
        data_dirs.append(d)
data_dirs.append("/usr/share")
data_dirs.append("/usr/local/share")
home = os.environ.get("HOME", "")
if home:
    data_dirs.insert(0, home + "/.local/share")
    data_dirs.insert(0, home + "/.local/share/flatpak/exports/share")

seen = set()

def parse_line(section, key):
    prefix = key + "="
    for line in section:
        l = line.strip()
        if l.startswith(prefix):
            return l[len(prefix):].strip()
    return ""

def desktop_files():
    for base in data_dirs:
        apps_dir = os.path.join(base, "applications")
        for path in glob.glob(os.path.join(apps_dir, "*.desktop")):
            real = os.path.realpath(path)
            if real in seen:
                continue
            seen.add(real)
            yield real

out = sys.stdout
for path in desktop_files():
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        continue

    # find the [Desktop Entry] section
    entry_start = None
    for i, line in enumerate(lines):
        if line.strip() == "[Desktop Entry]":
            entry_start = i
            break
    if entry_start is None:
        continue

    # read section until next header
    section = []
    for line in lines[entry_start + 1:]:
        if line.startswith("["):
            break
        section.append(line)

    if parse_line(section, "Type") not in ("Application", ""):
        continue
    if parse_line(section, "NoDisplay").lower() == "true":
        continue
    if parse_line(section, "Hidden").lower() == "true":
        continue

    name = parse_line(section, "Name")
    generic = parse_line(section, "GenericName")
    icon = parse_line(section, "Icon")
    exec_s = parse_line(section, "Exec")
    app_id = os.path.basename(path)

    if not name:
        continue
    if hidden(app_id, exec_s, name):
        continue

    fields = [name, generic, icon, app_id, exec_s]
    for i in range(len(fields)):
        fields[i] = fields[i].replace("\t", " ").replace("\n", " ")
    out.write("\t".join(fields) + "\n")
