-- Pyramid OS Hyprland configuration

local terminal = "ghostty"
local mainMod = "SUPER"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 2,
        col = {
            active_border = "rgba(e5e5e5ff)",
            inactive_border = "rgba(3a3a3aff)",
        },
        layout = "dwindle",
        allow_tearing = false,
        resize_on_border = true,
    },
    decoration = {
        rounding = 5,
        active_opacity = 1.00,
        inactive_opacity = 1.00,
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
        },
        shadow = {
            enabled = false,
            range = 4,
        },
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = false },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
})

-- Curves (official Hyprland examples)
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

-- Animations (official Hyprland defaults)
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- autostart (exec-once: runs only on Hyprland start, not every reload)
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -c bar")
    hl.exec_cmd("hyprpaper")
end)

local HOME = os.getenv("HOME")
local bin = HOME .. "/.config/hypr/scripts/"

local function script(name, args)
    return hl.dsp.exec_cmd(bin .. name .. (args and (" " .. args) or ""))
end

-- ────────────────────────────────────────────────────────────
-- applications
-- ────────────────────────────────────────────────────────────
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind("SUPER + SHIFT + RETURN", hl.dsp.exec_cmd("helium-browser"), { description = "Browser" })
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("helium-browser"), { description = "Browser" })
hl.bind("SUPER + SHIFT + ALT + B", hl.dsp.exec_cmd("helium-browser --incognito"), { description = "Browser (private)" })
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("nautilus --new-window"), { description = "File manager" })
hl.bind("SUPER + ALT + SHIFT + F", script("open-cwd.sh"), { description = "File manager (cwd)" })

-- Web apps
hl.bind("SUPER + SHIFT + A", script("webapp.sh", "https://chatgpt.com"), { description = "ChatGPT" })
hl.bind("SUPER + SHIFT + ALT + A", script("webapp.sh", "https://grok.com"), { description = "Grok" })
hl.bind("SUPER + SHIFT + C", script("webapp.sh", "https://app.hey.com/calendar/weeks/"), { description = "Calendar" })
hl.bind("SUPER + SHIFT + E", script("webapp.sh", "https://app.hey.com"), { description = "Email" })
hl.bind("SUPER + SHIFT + Y", script("webapp.sh", "https://youtube.com/"), { description = "YouTube" })
hl.bind("SUPER + SHIFT + ALT + G", script("webapp.sh", "https://web.whatsapp.com/"), { description = "WhatsApp" })
hl.bind("SUPER + SHIFT + CTRL + G", script("webapp.sh", "https://messages.google.com/web/conversations"), { description = "Google Messages" })
hl.bind("SUPER + SHIFT + P", script("webapp.sh", "https://photos.google.com/"), { description = "Google Photos" })
hl.bind("SUPER + SHIFT + S", script("webapp.sh", "https://maps.google.com/"), { description = "Google Maps" })
hl.bind("SUPER + SHIFT + X", script("webapp.sh", "https://x.com/"), { description = "X" })
hl.bind("SUPER + SHIFT + ALT + X", script("webapp.sh", "https://x.com/compose/post"), { description = "X Post" })

-- ────────────────────────────────────────────────────────────
-- window management / tiling
-- ────────────────────────────────────────────────────────────
hl.bind("SUPER + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind("CTRL + ALT + DELETE", script("close-all.sh"), { description = "Close all windows" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Toggle window split" })
hl.bind("SUPER + P", hl.dsp.window.pseudo(), { description = "Pseudo window" })
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle window floating/tiling" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Full screen" })
hl.bind("SUPER + CTRL + F", script("tiled-fullscreen.sh"), { description = "Tiled full screen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Full width" })
hl.bind("SUPER + O", script("window-pop.sh"), { description = "Pop window out (float & pin)" })
hl.bind("SUPER + ALT + Home", script("window-width.sh", "save"), { description = "Save window width" })
hl.bind("SUPER + Home", script("window-width.sh", "restore"), { description = "Restore window width" })
hl.bind("SUPER + L", script("workspace-layout.sh"), { description = "Toggle workspace layout" })
hl.bind("SUPER + BACKSPACE", script("window-transparency.sh"), { description = "Toggle window transparency" })
hl.bind("SUPER + SHIFT + BACKSPACE", script("window-gaps.sh"), { description = "Toggle window gaps" })

-- focus
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }), { description = "Focus on left window" })
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }), { description = "Focus on right window" })
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }), { description = "Focus on above window" })
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }), { description = "Focus on below window" })

-- workspaces
for workspace = 1, 10 do
    local key = "code:" .. tostring(workspace + 9)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(workspace) }), { description = "Switch to workspace " .. workspace })
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(workspace) }), { description = "Move window to workspace " .. workspace })
    hl.bind("SUPER + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = tostring(workspace), follow = false }), { description = "Move window silently to workspace " .. workspace })
end

-- scratchpad
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"), { description = "Toggle scratchpad" })
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Move window to scratchpad" })
hl.bind("SUPER + grave", hl.dsp.workspace.toggle_special("scratchpad"), { description = "Toggle scratchpad" })
hl.bind("SUPER + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Move window to scratchpad" })

-- workspace switching
hl.bind("SUPER + TAB", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind("SUPER + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })
hl.bind("SUPER + CTRL + TAB", hl.dsp.focus({ workspace = "previous" }), { description = "Former workspace" })

-- move workspace between monitors
hl.bind("SUPER + SHIFT + ALT + LEFT", hl.dsp.workspace.move({ monitor = "l" }), { description = "Move workspace to left monitor" })
hl.bind("SUPER + SHIFT + ALT + RIGHT", hl.dsp.workspace.move({ monitor = "r" }), { description = "Move workspace to right monitor" })
hl.bind("SUPER + SHIFT + ALT + UP", hl.dsp.workspace.move({ monitor = "u" }), { description = "Move workspace to up monitor" })
hl.bind("SUPER + SHIFT + ALT + DOWN", hl.dsp.workspace.move({ monitor = "d" }), { description = "Move workspace to down monitor" })

-- swap windows
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.swap({ direction = "l" }), { description = "Swap window to the left" })
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }), { description = "Swap window to the right" })
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.swap({ direction = "u" }), { description = "Swap window up" })
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.swap({ direction = "d" }), { description = "Swap window down" })

-- window cycling
hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), { description = "Focus on next window" })
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }), { description = "Focus on previous window" })

-- cross-monitor focus
hl.bind("CTRL + ALT + TAB", hl.dsp.focus({ monitor = "+1" }), { description = "Focus on next monitor" })
hl.bind("CTRL + ALT + SHIFT + TAB", hl.dsp.focus({ monitor = "-1" }), { description = "Focus on previous monitor" })

-- resizing (code:20 = -, code:21 = =)
hl.bind("SUPER + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { description = "Expand window left" })
hl.bind("SUPER + code:21", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { description = "Shrink window left" })
hl.bind("SUPER + SHIFT + code:20", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { description = "Shrink window up" })
hl.bind("SUPER + SHIFT + code:21", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { description = "Expand window down" })
hl.bind("SUPER + ALT + code:20", hl.dsp.window.resize({ x = -25, y = 0, relative = true }), { description = "Expand window left a little" })
hl.bind("SUPER + ALT + code:21", hl.dsp.window.resize({ x = 25, y = 0, relative = true }), { description = "Shrink window left a little" })
hl.bind("SUPER + SHIFT + ALT + code:20", hl.dsp.window.resize({ x = 0, y = -25, relative = true }), { description = "Shrink window up a little" })
hl.bind("SUPER + SHIFT + ALT + code:21", hl.dsp.window.resize({ x = 0, y = 25, relative = true }), { description = "Expand window down a little" })
hl.bind("SUPER + CTRL + code:20", hl.dsp.window.resize({ x = -300, y = 0, relative = true }), { description = "Expand window left a lot" })
hl.bind("SUPER + CTRL + code:21", hl.dsp.window.resize({ x = 300, y = 0, relative = true }), { description = "Shrink window left a lot" })
hl.bind("SUPER + CTRL + SHIFT + code:20", hl.dsp.window.resize({ x = 0, y = -300, relative = true }), { description = "Shrink window up a lot" })
hl.bind("SUPER + CTRL + SHIFT + code:21", hl.dsp.window.resize({ x = 0, y = 300, relative = true }), { description = "Expand window down a lot" })

-- mouse
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Scroll active workspace forward" })
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Scroll active workspace backward" })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
hl.bind("SUPER + ALT + mouse_down", hl.dsp.group.next(), { description = "Next window in group" })
hl.bind("SUPER + ALT + mouse_up", hl.dsp.group.prev(), { description = "Previous window in group" })

-- grouping
hl.bind("SUPER + G", hl.dsp.group.toggle(), { description = "Toggle window grouping" })
hl.bind("SUPER + ALT + G", hl.dsp.window.move({ out_of_group = true }), { description = "Move active window out of group" })
hl.bind("SUPER + ALT + LEFT", hl.dsp.window.move({ into_group = "l" }), { description = "Move window to group on left" })
hl.bind("SUPER + ALT + RIGHT", hl.dsp.window.move({ into_group = "r" }), { description = "Move window to group on right" })
hl.bind("SUPER + ALT + UP", hl.dsp.window.move({ into_group = "u" }), { description = "Move window to group on top" })
hl.bind("SUPER + ALT + DOWN", hl.dsp.window.move({ into_group = "d" }), { description = "Move window to group on bottom" })
hl.bind("SUPER + ALT + TAB", hl.dsp.group.next(), { description = "Next window in group" })
hl.bind("SUPER + ALT + SHIFT + TAB", hl.dsp.group.prev(), { description = "Previous window in group" })
hl.bind("SUPER + CTRL + LEFT", hl.dsp.group.prev(), { description = "Move grouped window focus left" })
hl.bind("SUPER + CTRL + RIGHT", hl.dsp.group.next(), { description = "Move grouped window focus right" })
for index = 1, 5 do
    hl.bind("SUPER + ALT + code:" .. tostring(index + 9), hl.dsp.group.active({ index = index }), { description = "Switch to group window " .. index })
end

-- monitor scaling
hl.bind("SUPER + SLASH", script("monitor-scaling.sh", "up"), { description = "Monitor scaling up" })
hl.bind("SUPER + ALT + SLASH", script("monitor-scaling.sh", "down"), { description = "Monitor scaling down" })

-- ────────────────────────────────────────────────────────────
-- utilities
-- ────────────────────────────────────────────────────────────
    hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs -c bar ipc call launcher toggle"), { description = "Launcher" })
hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("qs -c bar ipc call powermenu toggle"), { description = "Power menu" })
hl.bind("SUPER + SHIFT + SPACE", script("bar-toggle.sh"), { description = "Toggle top bar" })

hl.bind("SUPER + CTRL + L", script("system-lock.sh"), { locked = true, description = "Lock system" })
hl.bind("SUPER + CTRL + I", script("idle-toggle.sh"), { description = "Toggle locking on idle" })

hl.bind("SUPER + CTRL + Z", function()
    local zoom = hl.get_config("cursor.zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = zoom + 1 } })
end, { description = "Zoom in" })
hl.bind("SUPER + CTRL + ALT + Z", function()
    hl.config({ cursor = { zoom_factor = 1 } })
end, { description = "Reset zoom" })

-- capture
hl.bind("PRINT", script("screenshot.sh"), { description = "Screenshot" })
hl.bind("SUPER + CTRL + C", script("screenshot.sh", "region"), { description = "Screenshot region" })
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"), { description = "Color picker" })
