//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // ── behaviour ──────────────────────────────────────────
    property bool useWalker: false
    property bool launcherOpen: false
    property bool powerOpen: false
    property int  powerSel: 0
    property bool desktopControlOpen: false
    property real lowerAnimScale: 1.0
    property string openPanel: ""   // "cal" | "wifi" | "bt" | "bri" | "bat" | "notif" | "rem" | "vol"

    // ── user config ──────────────────────────────────────
    property var userConfig: {
        "barHeight": 34,
        "roundness": 5,
        "animationSpeed": 220,
        "panelAnimation": 280,
        "showSeconds": false,
        "favorites": ["firefox", "terminal", "code"],
        "debugMode": false
    }

    // ── design tokens — 8pt grid, intentional spacing ──────
    readonly property int round: userConfig.roundness
    readonly property int s4: 4
    readonly property int s6: 6
    readonly property int s8: 8
    readonly property int s12: 12
    readonly property int s16: 16
    readonly property int s20: 20
    readonly property int barH: userConfig.barHeight
    readonly property int barInnerPad: 8
    readonly property int iconS: 16
    readonly property int animFast: 140
    readonly property int animNorm: userConfig.animationSpeed
    readonly property int animSlow: 320
    readonly property int animPanel: userConfig.panelAnimation

    // ══ SOLITUDE PALETTE ═══════════════════════════════════
    readonly property color bg:        "#12141f"
    readonly property color bgLight:   "#1e2233"
    readonly property color bgHover:   "#252a3f"
    readonly property color borderCol: "#2b3046"
    readonly property color borderHi:  "#3a4160"
    readonly property color fg:        "#c3c8dd"
    readonly property color dim:       "#767da0"
    readonly property color accent:    "#96a7f2"
    readonly property color accentDim: "#7a86c8"
    readonly property color green:     "#9dc6a8"
    readonly property color red:       "#d0808a"
    readonly property color yellow:    "#d9c48a"
    // ═══════════════════════════════════════════════════════
    readonly property string fontName: "JetBrainsMono Nerd Font"

    // ── icons ──────────────────────────────────────────────
    readonly property string iLaunch: "\uf135"
    readonly property string iWifi:   "\uf1eb"
    readonly property string iBt:     "\uf294"
    readonly property string iSun:    "\uf185"
    readonly property string iBell:   "\uf0f3"
    readonly property string iClock:  "\uf017"
    readonly property string iMoon:   "\uf186"
    readonly property string iLock:   "\uf023"
    readonly property string iCheck:  "\uf00c"
    readonly property string iVolMute:  "\uf026"
    readonly property string iVolLow:   "\uf027"
    readonly property string iVolHigh:  "\uf028"
    readonly property string iPower:    "\uf011"
    readonly property string iReboot:   "\uf021"
    readonly property string iSleep:    "\uf186"
    readonly property string iHibernate:"\uf236"
    readonly property string iLogout:   "\uf08b"
    readonly property string iDesktop:  "\uf108"
    readonly property string iDisplay:  "\uf26c"
    readonly property string iDown:     "\uf078"
    readonly property string iDownArrow:"\uf063"
    readonly property string iUp:       "\uf077"
    readonly property string iSearch:   "\uf002"

    // ── state ──────────────────────────────────────────────
    property bool btPowered: false
    property int  btConnected: 0
    property var  btDevices: []
    property bool wifiEnabled: false
    property int  wifiSignal: -1
    property var  networks: []
    property string pendingSsid: ""
    property int  brightness: 0
    property bool briAvail: false
    property string briError: ""
    property var  notifs: []
    property bool dnd: false
    property var  reminders: []
    property string remHint: ""
    property int  nowTick: Date.now()
    property bool batPresent: false
    property int  batCap: 0
    property string batStatus: ""
    property string batFamily: ""
    property real  batNow: 0
    property real  batFull: 0
    property real  batRate: 0
    property int  batHealth: 100
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var  recentApps: []
    property var  favorites: userConfig.favorites
    property bool debugMode: userConfig.debugMode

    // ── PipeWire volume ────────────────────────────────────
    readonly property var pwSink: Pipewire.defaultAudioSink
    readonly property bool pwReady: Pipewire.ready && pwSink !== null
    readonly property real volLevel: pwReady && pwSink.audio ? pwSink.audio.volume : volFallback
    readonly property bool volMuted: pwReady && pwSink.audio ? pwSink.audio.muted : volMutedFallback
    property real volFallback: 0.5
    property bool volMutedFallback: false
    readonly property string volIcon: volMuted ? iVolMute : volLevel < 0.32 ? iVolLow : iVolHigh

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (pwReady && pwSink.audio) pwSink.audio.volume = v;
        else {
            const pct = Math.round(v * 100);
            volFallback = v;
            volProc.cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + pct + "% 2>/dev/null || pactl set-sink-volume @DEFAULT_SINK@ " + pct + "% 2>/dev/null";
            volProc.running = true;
        }
    }

    function adjVolume(d) { setVolume(volLevel + d); }

    Process {
        id: volProc
        property string cmd: ""
        command: ["sh", "-c", cmd]
        onExited: volRefresh.running = true
    }

    Process {
        id: volRefresh
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -oE '[0-9.]+' | head -n1; wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo muted || echo unmuted"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                const v = parseFloat(l[0]);
                if (!isNaN(v)) root.volFallback = v;
                if (l[1] === "muted") root.volMutedFallback = true;
                else if (l[1] === "unmuted") root.volMutedFallback = false;
            }
        }
    }

    // ── battery derived ────────────────────────────────────
    readonly property bool batCharging: batStatus.indexOf("Charg") === 0
    readonly property bool batIsFull:   batStatus.indexOf("Full") === 0
    readonly property bool batAlert: batPresent && !batCharging && !batIsFull && batCap < 15
    readonly property string batIcon:
        !batPresent   ? "" :
        batCharging   ? "\uf0e7" :
        batCap >= 90  ? "\uf240" :
        batCap >= 60  ? "\uf241" :
        batCap >= 30  ? "\uf242" :
        batCap >= 15  ? "\uf243" : "\uf244"

    function log(msg) {
        if (debugMode) console.log("[Bar] " + msg);
    }

    function batEstimate() {
        if (!batPresent || batRate <= 0 || batNow <= 0) return "";
        const charging = batCharging;
        const mins = charging
            ? (batFull - batNow) / batRate * 60
            : batNow / batRate * 60;
        if (!isFinite(mins) || mins <= 0 || mins > 6000) return "";
        const h = Math.floor(mins / 60), m = Math.round(mins % 60);
        const t = (h > 0 ? h + "h " : "") + m + "m";
        return charging ? "~" + t + " to full" : "~" + t + " left";
    }

    function closePanel() { root.openPanel = ""; }

    function togglePanel(name) {
        if (root.powerOpen) root.powerOpen = false;
        if (root.launcherOpen) root.launcherOpen = false;
        if (root.desktopControlOpen) root.desktopControlOpen = false;
        root.openPanel = (root.openPanel === name ? "" : name);
        if (root.openPanel === "bt") btDevicesProc.running = true;
        if (root.openPanel === "wifi") wifiScan.running = true;
    }

    function closeAllOverlays() {
        root.launcherOpen = false;
        root.powerOpen = false;
        root.desktopControlOpen = false;
        root.openPanel = "";
    }

    function toggleLauncher() {
        const willOpen = !root.launcherOpen;
        root.launcherOpen = willOpen;
        if (willOpen) { root.powerOpen = false; root.desktopControlOpen = false; root.openPanel = ""; }
    }

    function togglePower() {
        const willOpen = !root.powerOpen;
        root.powerOpen = willOpen;
        if (willOpen) { root.launcherOpen = false; root.desktopControlOpen = false; root.openPanel = ""; root.powerSel = 0; }
    }

    function toggleDesktop() {
        const willOpen = !root.desktopControlOpen;
        root.desktopControlOpen = willOpen;
        if (willOpen) { root.launcherOpen = false; root.powerOpen = false; root.openPanel = ""; }
    }

    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }

    function connectWifi(ssid, pass) {
        log("Connecting to wifi: " + ssid);
        nmAction.cmd = "nmcli device wifi connect " + shq(ssid) +
                       (pass ? " password " + shq(pass) : "");
        nmAction.running = true;
        root.pendingSsid = "";
    }

    function dismiss(n) { 
        try {
            n.obj.close(); 
            root.notifs = root.notifs.filter(x => x !== n);
        } catch(e) {
            log("Error dismissing notification: " + e);
        }
    }

    function clearNotifs() {
        for (const n of root.notifs) {
            try { n.obj.close(); } catch(e) {}
        }
        root.notifs = [];
    }

    // ── power entries ──────────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME") || "/home/prakhyat"
    readonly property var powerEntries: [
        { label: "Lock",      icon: root.iLock,     desc: "Lock screen",               cmd: (homeDir + "/.config/hypr/scripts/system-lock.sh") },
        { label: "Idle",      icon: root.iMoon,     desc: "Run pyramid screensaver",  cmd: (homeDir + "/.local/bin/pyramid-launch-screensaver") },
        { label: "Log Out",   icon: root.iLogout,   desc: "Exit Hyprland session",      cmd: "hyprctl dispatch exit" },
        { label: "Suspend",   icon: root.iSleep,    desc: "Sleep — suspend to RAM",     cmd: "systemctl suspend" },
        { label: "Hibernate", icon: root.iHibernate,desc: "Hibernate — suspend to disk",cmd: "systemctl hibernate" },
        { label: "Reboot",    icon: root.iReboot,   desc: "Restart system",             cmd: "systemctl reboot" },
        { label: "Shutdown",  icon: root.iPower,    desc: "Power off",                  cmd: "systemctl poweroff" }
    ]

    Process { 
        id: powerAction
        property string cmd: ""
        command: ["sh", "-c", cmd]
        onExited: log("Power action completed: " + cmd)
    }

    function runPower(entry) {
        if (!entry) return;
        log("Running power action: " + entry.label);
        root.powerOpen = false;
        root.desktopControlOpen = false;
        if (entry.label === "Lock") { 
            powerAction.cmd = entry.cmd; 
            powerAction.running = true; 
        } else if (entry.label === "Idle") { 
            Quickshell.execDetached(["sh", "-c", entry.cmd + " &"]);
        } else if (entry.label === "Log Out") { 
            Quickshell.execDetached(["sh", "-c", entry.cmd + " &"]); 
        } else { 
            Quickshell.execDetached(["sh", "-c", "sleep 0.32; " + entry.cmd]); 
        }
    }

    // ── reminder helpers ───────────────────────────────────
    function parseWhen(s) {
        s = s.trim().toLowerCase();
        if (s === "tomorrow") { 
            const t = new Date(); 
            t.setDate(t.getDate()+1); 
            t.setHours(9,0,0,0); 
            return t.getTime(); 
        }
        let m = s.match(/^(\d+)\s*m?(in|min)?$/);
        if (m) return Date.now() + parseInt(m[1]) * 60000;
        m = s.match(/^(\d+)\s*(h|hr|hour|hours)$/);
        if (m) return Date.now() + parseInt(m[1]) * 3600000;
        m = s.match(/^(\d+)\s*h\s*(\d+)\s*m?$/);
        if (m) return Date.now() + (parseInt(m[1]) * 3600 + parseInt(m[2]) * 60) * 1000;
        m = s.match(/^(\d{1,2}):(\d{2})$/);
        if (m) {
            const t = new Date();
            t.setHours(parseInt(m[1]), parseInt(m[2]), 0, 0);
            if (t.getTime() <= Date.now()) t.setDate(t.getDate() + 1);
            return t.getTime();
        }
        m = s.match(/^tomorrow\s+(\d{1,2}):(\d{2})$/);
        if (m) { 
            const t = new Date(); 
            t.setDate(t.getDate()+1); 
            t.setHours(parseInt(m[1]), parseInt(m[2]), 0, 0); 
            return t.getTime(); 
        }
        return 0;
    }

    function fmtLeftAt(when, now) {
        const s = Math.max(0, Math.round((when - now) / 1000));
        if (s < 60) return "in " + s + "s";
        const m = Math.floor(s / 60);
        if (m < 60) return "in " + m + "m";
        const h = Math.floor(m / 60);
        return "in " + h + "h" + (m % 60 ? (m % 60) + "m" : "");
    }

    function saveReminders() {
        remSaveProc.cmd = "mkdir -p \"$HOME/.local/share/quickshell\"; " +
            "printf %s " + shq(JSON.stringify(root.reminders)) +
            " > \"$HOME/.local/share/quickshell/reminders.json\"";
        remSaveProc.running = true;
    }

    function addReminder(text, whenStr) {
        const t = text.trim();
        const when = parseWhen(whenStr);
        if (!t) { root.remHint = "type what to remind you about"; return; }
        if (!when) { root.remHint = "when: 15m · 1h30 · 14:30 · tomorrow 09:00"; return; }
        root.reminders = root.reminders.concat([{ when: when, text: t }])
                             .sort((a, b) => a.when - b.when);
        saveReminders();
        root.remHint = "";
        remText.text = ""; remWhen.text = "";
        log("Reminder added: " + t);
    }

    function delReminder(r) {
        root.reminders = root.reminders.filter(x => x !== r);
        saveReminders();
        log("Reminder deleted");
    }

    // ── Lower — smooth scroll to next section ──────────────
    function smoothScroll(list, amount) {
        if (!list || !list.flickableItem) return;
        const f = list.flickableItem;
        const target = f.contentY !== undefined ? f : list;
        const page = Math.round(list.height * 0.88);
        const maxY = Math.max(0, target.contentHeight - list.height);
        const next = Math.min(maxY, target.contentY + page);
        if (Math.abs(target.contentY - maxY) < 4 && maxY > 0) {
            target.contentY = 0;
            return;
        }
        target.contentY = next;
    }

    function scrollNextSection() {
        log("Lower pressed - scrolling next section");
        lowerPressAnim.restart();
        if (root.launcherOpen) { smoothScroll(appList, 1); return; }
        if (root.powerOpen) {
            const max = Math.max(0, powerList.contentHeight - powerList.height);
            powerList.contentY = Math.min(max, powerList.contentY + powerList.height*0.9);
            return;
        }
        switch (root.openPanel) {
            case "wifi":  smoothScroll(wifiList, 1); break;
            case "bt":    smoothScroll(btList, 1); break;
            case "notif": smoothScroll(notifList, 1); break;
            case "rem":   smoothScroll(remList, 1); break;
            case "cal":   calWin.viewDate = calWin.addMonths(calWin.viewDate, 1); break;
            case "vol":   root.adjVolume(-0.05); break;
            case "bri":   briSet.cmd = "set 5%-"; briSet.running = true; break;
            case "bat":   break;
            default:
                Hyprland.dispatch("workspace e+1");
                wsPulse.restart();
                break;
        }
    }

    SequentialAnimation {
        id: lowerPressAnim
        NumberAnimation { target: root; property: "lowerAnimScale"; from: 1; to: 0.88; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "lowerAnimScale"; from: 0.88; to: 1.06; duration: 160; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "lowerAnimScale"; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: wsPulse
        NumberAnimation { target: wsRow; property: "scale"; from: 1; to: 1.04; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: wsRow; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ══ IPC ────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleLauncher(); }
        function open(): void { if (!root.launcherOpen) root.toggleLauncher(); }
        function close(): void { if (root.launcherOpen) root.launcherOpen = false; }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.togglePower(); }
        function open(): void { if (!root.powerOpen) root.togglePower(); }
        function close(): void { if (root.powerOpen) root.powerOpen = false; }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.togglePower(); }
        function open(): void { if (!root.powerOpen) root.togglePower(); }
        function close(): void { if (root.powerOpen) root.powerOpen = false; }
    }

    IpcHandler {
        target: "desktop"
        function toggle(): void { root.desktopControlOpen = !root.desktopControlOpen; }
        function open(): void { root.desktopControlOpen = true; }
        function close(): void { root.desktopControlOpen = false; }
    }

    IpcHandler {
        target: "bar"
        function togglePanel(name: string): void { root.togglePanel(name); }
        function closeAll(): void { root.closeAllOverlays(); }
        function lower(): void { root.scrollNextSection(); }
    }

    // ══ NOTIFICATIONS ══════════════════════════════════════
    NotificationServer {
        id: notifServer
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: notification => {
            if (root.dnd) { notification.close(); return; }
            log("Notification received: " + notification.summary);
            const ms = notification.expireTimeout;
            root.notifs = root.notifs.concat([{
                obj: notification,
                title: notification.summary,
                body: notification.body,
                app: notification.appName,
                expires: ms > 0 ? Date.now() + ms : 0,
                time: Date.now()
            }]);
            if (root.notifs.length > 20) {
                try { root.notifs[0].obj.close(); } catch(e) {}
                root.notifs = root.notifs.slice(1);
            }
            notifPulse.restart();
        }
    }

    SequentialAnimation {
        id: notifPulse
        NumberAnimation { target: notifBtn; property: "scale"; from:1; to:1.18; duration:120; easing.type:Easing.OutCubic }
        NumberAnimation { target: notifBtn; property: "scale"; to:1; duration:220; easing.type:Easing.OutBack }
    }

    Timer {
        interval: 1000; repeat: true; running: root.notifs.length > 0
        onTriggered: {
            const now = Date.now();
            const keep = root.notifs.filter(n => n.expires === 0 || n.expires > now);
            if (keep.length !== root.notifs.length) root.notifs = keep;
        }
    }

    // ══ REMINDER ENGINE ════════════════════════════════════
    Process {
        id: remLoadProc
        command: ["sh", "-c", "cat \"$HOME/.local/share/quickshell/reminders.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const arr = JSON.parse(text);
                    if (Array.isArray(arr))
                        root.reminders = arr.filter(r => r.when > Date.now())
                                            .sort((a, b) => a.when - b.when);
                } catch (e) { log("Error loading reminders: " + e); }
            }
        }
    }

    Process { 
        id: remSaveProc
        property string cmd: ""
        command: ["sh", "-c", cmd]
    }

    Process { 
        id: notifyProc
        property string cmd: ""
        command: ["sh", "-c", cmd]
    }

    Component.onCompleted: { 
        remLoadProc.running = true; 
        volRefresh.running = true;
        log("Bar initialized");
    }

    Timer {
        interval: 10000; repeat: true; running: true
        onTriggered: {
            root.nowTick = Date.now();
            const due = root.reminders.filter(r => r.when <= Date.now());
            if (due.length) {
                notifyProc.cmd = due.map(r =>
                    "notify-send -a Shell 'Reminder' " + shq(r.text)).join("; ");
                notifyProc.running = true;
                root.reminders = root.reminders.filter(r => r.when > Date.now());
                saveReminders();
            }
        }
    }

    // ══ BATTERY ════════════════════════════════════════════
    Process {
        id: batProc
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "[ -z \"$b\" ] && { echo none; exit 0; }; " +
            "cat \"$b/capacity\" 2>/dev/null; cat \"$b/status\" 2>/dev/null; " +
            "if [ -r \"$b/energy_now\" ]; then " +
            "  echo \"E $(cat $b/energy_now 2>/dev/null) $(cat $b/energy_full 2>/dev/null) $(cat $b/power_now 2>/dev/null || echo 0)\"; " +
            "elif [ -r \"$b/charge_now\" ]; then " +
            "  echo \"C $(cat $b/charge_now 2>/dev/null) $(cat $b/charge_full 2>/dev/null) $(cat $b/current_now 2>/dev/null || echo 0)\"; " +
            "fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (!l[0] || l[0] === "none") { root.batPresent = false; return; }
                root.batPresent = true;
                root.batCap = parseInt(l[0]) || 0;
                root.batStatus = (l[1] || "").trim();
                const m = (l[2] || "").split(/\s+/);
                if (m[0] === "E" || m[0] === "C") {
                    root.batFamily = m[0];
                    root.batNow  = parseFloat(m[1]) || 0;
                    root.batFull = parseFloat(m[2]) || 0;
                    root.batRate = parseFloat(m[3]) || 0;
                }
                batHealthProc.running = true;
            }
        }
    }

    Process {
        id: batHealthProc
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "[ -z \"$b\" ] && echo 100; " +
            "design=$(cat \"$b/energy_full_design\" 2>/dev/null || cat \"$b/charge_full_design\" 2>/dev/null || echo 0); " +
            "current=$(cat \"$b/energy_full\" 2>/dev/null || cat \"$b/charge_full\" 2>/dev/null || echo 0); " +
            "[ \"$design\" -gt 0 ] && echo $((current * 100 / design)) || echo 100"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = parseInt(text.trim());
                if (!isNaN(h) && h > 0) root.batHealth = Math.min(100, h);
            }
        }
    }

    Process {
        id: btStatus
        command: ["sh", "-c",
            "bluetoothctl show | grep -q 'Powered: yes' && echo p1 || echo p0; " +
            "bluetoothctl devices Connected 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.btPowered = l[0] === "p1";
                root.btConnected = parseInt(l[1]) || 0;
            }
        }
    }

    Process {
        id: btDevicesProc
        command: ["sh", "-c",
            "bluetoothctl devices Paired 2>/dev/null | while read -r _ mac; do " +
            "info=$(bluetoothctl info $mac 2>/dev/null); " +
            "name=$(echo \"$info\" | sed -n 's/^[[:space:]]*Name: //p'); " +
            "conn=$(echo \"$info\" | sed -n 's/^[[:space:]]*Connected: //p'); " +
            "echo \"$mac|$name|$conn\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const p = line.trim().split("|");
                    if (p.length === 3 && p[0])
                        list.push({ mac: p[0], name: p[1] || p[0], connected: p[2] === "yes" });
                }
                root.btDevices = list;
            }
        }
    }

    Process {
        id: btAction
        property string cmd: ""
        command: ["sh", "-c", "bluetoothctl " + cmd]
        stdout: StdioCollector { 
            onStreamFinished: { 
                btStatus.running = true; 
                btDevicesProc.running = true; 
            } 
        }
    }

    Process {
        id: wifiStatus
        command: ["sh", "-c",
            "nmcli radio wifi; " +
            "nmcli -t -f ACTIVE,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1 ~ /yes/ {print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.wifiEnabled = (l[0] || "").indexOf("enabled") === 0;
                const s = parseInt(l[1]);
                root.wifiSignal = isNaN(s) ? -1 : s;
            }
        }
    }

    Process {
        id: wifiScan
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const p = line.split(":");
                    if (p.length < 4) continue;
                    const ssid = (p[1] || "").replace(/\\:/g, ":");
                    if (!ssid) continue;
                    const sig = parseInt(p[2]) || 0;
                    if (!map[ssid] || sig > map[ssid].signal)
                        map[ssid] = { ssid: ssid, signal: sig, sec: p[3] || "", active: p[0] === "yes" };
                }
                root.networks = Object.values(map).sort((a, b) => b.signal - a.signal);
            }
        }
    }

    Process {
        id: nmAction
        property string cmd: ""
        command: ["sh", "-c", cmd]
        stdout: StdioCollector { 
            onStreamFinished: { 
                wifiStatus.running = true; 
                wifiScan.running = true; 
            } 
        }
    }

    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || "";
                if (!line || /no backlight|not found/i.test(line)) {
                    root.briAvail = false;
                    root.briError = "no backlight found";
                    return;
                }
                const pct = line.split(",").find(f => f.trim().endsWith("%"));
                if (pct) root.brightness = parseInt(pct) || 0;
                root.briAvail = true;
                if (!briSlider.pressed) briSlider.value = root.brightness;
                if (!desktopBriSlider.pressed) desktopBriSlider.value = root.brightness;
            }
        }
    }

    Process {
        id: briSet
        property string cmd: ""
        command: ["sh", "-c", "brightnessctl " + cmd]
        stdout: StdioCollector { 
            onStreamFinished: { 
                briProc.running = true; 
                log("Brightness set: " + cmd);
            } 
        }
        stderr: StdioCollector { 
            onStreamFinished: {
                root.briError = text.trim();
                if (text.includes("permission")) {
                    root.briError += " — fix: sudo usermod -aG video $USER, then relog";
                }
            } 
        }
    }

    Process {
        id: netSpeed
        command: ["sh", "-c", "ifstat -i wlan0 0.5 1 2>/dev/null | tail -n1 || echo '0 0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 2) {
                    root.downloadSpeed = parseFloat(parts[0]) || 0;
                    root.uploadSpeed = parseFloat(parts[1]) || 0;
                }
            }
        }
    }

    // Combined timer for efficiency
    Timer {
        interval: 5000
        triggeredOnStart: true
        repeat: true
        running: true
        onTriggered: { 
            btStatus.running = true; 
            wifiStatus.running = true;
            briProc.running = true; 
            batProc.running = true;
            netSpeed.running = true;
        }
    }

    Timer {
        interval: 4000
        triggeredOnStart: true
        repeat: true
        running: root.openPanel === "bt"
        onTriggered: btDevicesProc.running = true
    }

    Timer {
        interval: 6000
        triggeredOnStart: true
        repeat: true
        running: root.openPanel === "wifi"
        onTriggered: wifiScan.running = true
    }

    Shortcut {
        sequences: ["Escape"]
        onActivated: root.closeAllOverlays()
        context: Qt.ApplicationShortcut
    }

    // ══ reusable — polished, animated ──────────────────────
    component IconBtn: Rectangle {
        id: btn
        property string icon
        property bool dimmed: false
        property bool accented: false
        signal activated()
        signal wheeled(int delta)
        width: 34; height: 26; radius: root.round
        scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.04 : 1)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        color: ma.containsMouse ? root.bgHover : "transparent"
        border.color: ma.containsMouse ? root.borderHi : "transparent"
        border.width: ma.containsMouse ? 1 : 0
        Behavior on color { ColorAnimation { duration: root.animFast } }
        Behavior on border.color { ColorAnimation { duration: root.animFast } }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: root.fontName
            font.pixelSize: 16; font.bold: true
            color: btn.dimmed ? root.dim : (btn.accented ? root.accent : root.fg)
            Behavior on color { ColorAnimation { duration: root.animFast } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
            onWheel: w => btn.wheeled(w.angleDelta.y)
        }
        Accessible.role: Accessible.Button
        Accessible.name: btn.icon
        Accessible.description: "Icon button"
    }

    component BatBtn: Rectangle {
        id: bb
        width: 60; height: 26; radius: root.round
        scale: bma.pressed ? 0.95 : (bma.containsMouse ? 1.03 : 1)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        color: bma.containsMouse ? root.bgHover : "transparent"
        border.color: bma.containsMouse ? root.borderHi : "transparent"
        border.width: bma.containsMouse ? 1 : 0
        Behavior on color { ColorAnimation { duration: root.animFast } }
        Row {
            anchors.centerIn: parent
            spacing: 5
            Text {
                text: root.batIcon
                font.family: root.fontName; font.pixelSize: 16; font.bold: true
                color: root.batAlert ? root.red : (root.batCharging || root.batIsFull) ? root.green : root.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.batCap + "%"
                font.family: root.fontName; font.pixelSize: 11; font.bold: true
                color: root.batAlert ? root.red : root.dim
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: bma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePanel("bat")
            onWheel: w => { 
                briSet.cmd = w.angleDelta.y > 0 ? "set +5%" : "set 5%-"; 
                briSet.running = true; 
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Battery " + root.batCap + "%"
    }

    component CloseBtn: Rectangle {
        id: cb
        width: 22; height: 22; radius: root.round
        color: cma.containsMouse ? root.bgLight : "transparent"
        Behavior on color { ColorAnimation { duration: root.animFast } }
        Text { 
            anchors.centerIn: parent; 
            text: "×"; 
            color: cma.containsMouse ? root.fg : root.dim; 
            font.family: root.fontName; 
            font.pixelSize: 14; 
            font.bold: true 
        }
        signal clicked()
        MouseArea { 
            id: cma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked() 
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Close"
    }

    component PanelHeader: RowLayout {
        id: ph
        property string title
        Layout.fillWidth: true
        spacing: root.s8
        Rectangle { width: 3; height: 14; radius: 1.5; color: root.accent; Layout.alignment: Qt.AlignVCenter }
        Text { 
            text: ph.title; 
            color: root.dim; 
            font { family: root.fontName; pixelSize: 11; letterSpacing: 2; bold: true } 
            Layout.alignment: Qt.AlignVCenter 
        }
        Item { Layout.fillWidth: true }
        CloseBtn { onClicked: root.closePanel() }
    }

    component Divider: Rectangle { 
        Layout.fillWidth: true; 
        height: 1; 
        color: root.borderCol; 
        opacity: 0.7 
    }

    // ══ THE BAR — true 3-zone, absolutely centered time ────
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        margins { top: 5; left: 8; right: 8 }
        implicitHeight: root.barH
        color: "transparent"

        Rectangle {
            id: barBg
            anchors.fill: parent
            radius: root.round
            color: root.bg
            border.color: root.borderCol
            border.width: 1
            opacity: 1
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }

            Item {
                anchors.fill: parent
                anchors.leftMargin: root.barInnerPad
                anchors.rightMargin: root.barInnerPad

                // LEFT cluster — rocket only (desktop moved to far right)
                RowLayout {
                    id: leftCluster
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s8
                    IconBtn {
                        icon: root.iLaunch
                        accented: root.launcherOpen
                        onActivated: root.toggleLauncher()
                        Accessible.name: "Launcher"
                    }
                    Row {
                        id: wsRow
                        spacing: root.s4
                        Layout.alignment: Qt.AlignVCenter
                        visible: Hyprland.workspaces.count > 0
                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isActive: modelData.active
                                readonly property bool isFocused: modelData.focused
                                readonly property bool hasWindows: modelData.toplevels && modelData.toplevels.count > 0
                                width: isFocused ? 24 : 20; height: 20; radius: root.round
                                scale: maWs.containsMouse ? 1.08 : 1
                                Behavior on width { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: root.animFast } }
                                color: isFocused ? root.accent : (isActive ? root.bgLight : "transparent")
                                border.color: hasWindows && !isFocused && !isActive ? root.borderCol : (isActive && !isFocused ? root.borderHi : "transparent")
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    font.family: root.fontName; font.pixelSize: 10; font.bold: isFocused
                                    color: isFocused ? root.bg : (isActive ? root.fg : root.dim)
                                }
                                MouseArea {
                                    id: maWs
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + modelData.name)
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: "Workspace " + modelData.name
                            }
                        }
                    }
                    Row {
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        visible: SystemTray.items.count > 0
                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                required property SystemTrayItem modelData
                                width: 22; height: 22; radius: root.round
                                scale: ma.containsMouse ? 1.1 : 1
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                color: ma.containsMouse ? root.bgHover : "transparent"
                                IconImage {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    source: modelData.icon
                                    smooth: true
                                }
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) modelData.activate();
                                        else if (mouse.button === Qt.RightButton) modelData.secondaryActivate();
                                    }
                                    onWheel: w => {
                                        if (w.angleDelta.y > 0) modelData.scrollUp();
                                        else if (w.angleDelta.y < 0) modelData.scrollDown();
                                    }
                                }
                            }
                        }
                    }
                }

                // CENTER — absolutely centered
                Row {
                    id: centerRow
                    anchors.centerIn: parent
                    spacing: root.s8
                    IconBtn {
                        id: notifBtn
                        icon: root.iBell
                        accented: root.notifs.length > 0
                        dimmed: root.dnd && root.notifs.length === 0
                        onActivated: root.togglePanel("notif")
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "Notifications" + (root.notifs.length > 0 ? " (" + root.notifs.length + ")" : "")
                    }
                    Text {
                        id: timeText
                        text: Qt.formatDateTime(clock.date, userConfig.showSeconds ? "h:mm:ss ap" : "h:mm ap")
                        color: tma.containsMouse ? root.accent : root.fg
                        font.family: root.fontName; font.pixelSize: 13; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on color { ColorAnimation { duration: root.animFast } }
                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("cal")
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: "Calendar"
                    }
                    IconBtn {
                        id: remBtn
                        icon: root.iClock
                        accented: root.reminders.length > 0
                        onActivated: root.togglePanel("rem")
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "Reminders" + (root.reminders.length > 0 ? " (" + root.reminders.length + ")" : "")
                    }
                }

                // RIGHT cluster — battery & exit removed from normal bar (kept in desktop controls / power menu)
                RowLayout {
                    id: rightCluster
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.s8
                    IconBtn {
                        id: volBtn
                        icon: root.volIcon
                        dimmed: root.volMuted
                        accented: !root.volMuted && root.volLevel > 0
                        onActivated: root.togglePanel("vol")
                        onWheeled: d => root.adjVolume(d > 0 ? 0.05 : -0.05)
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "Volume " + Math.round(root.volLevel * 100) + "%"
                    }
                    IconBtn {
                        id: wifiBtn
                        icon: root.iWifi
                        dimmed: !root.wifiEnabled
                        accented: root.wifiEnabled && root.wifiSignal >= 0
                        onActivated: root.togglePanel("wifi")
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "WiFi" + (root.wifiEnabled ? " connected" : " off")
                    }
                    IconBtn {
                        id: btBtn
                        icon: root.iBt
                        dimmed: !root.btPowered
                        accented: root.btConnected > 0
                        onActivated: root.togglePanel("bt")
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "Bluetooth" + (root.btPowered ? " on" : " off") + (root.btConnected > 0 ? " connected" : "")
                    }
                    Rectangle { 
                        width: 1; height: 18; color: root.borderCol; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 
                    }
                    // Desktop — most right, scroll to control brightness
                    IconBtn {
                        id: desktopBtn
                        icon: root.iDesktop
                        accented: root.desktopControlOpen
                        onActivated: root.toggleDesktop()
                        onWheeled: d => {
                            briSet.cmd = d > 0 ? "set +5%" : "set 5%-";
                            briSet.running = true;
                        }
                        Layout.alignment: Qt.AlignVCenter
                        Accessible.name: "Desktop controls — scroll for brightness"
                    }
                }
            }
        }
    }

    // ══ DESKTOP CONTROLS ═══════════════════════════════════
    PanelWindow {
        id: desktopControlWin
        visible: root.desktopControlOpen
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: desktopControlWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.desktopControlOpen = false }
        }

        Rectangle {
            width: 380; height: 380
            x: 24
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: desktopControlWin.visible ? 1 : 0; scale: desktopControlWin.visible ? 1 : 0.97; y: desktopControlWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s12
                PanelHeader { title: "DESKTOP CONTROLS" }
                Divider {}

                // Battery row
                RowLayout {
                    Layout.fillWidth: true; spacing: root.s12
                    Rectangle { width: 28; height: 28; radius: root.round; color: root.batAlert ? root.red+"22" : (root.batCharging ? root.green+"22" : root.accent+"22")
                        Text { anchors.centerIn: parent; text: root.batIcon; font.family: root.fontName; font.pixelSize: 16; font.bold: true; color: root.batAlert ? root.red : (root.batCharging || root.batIsFull) ? root.green : root.fg }
                        Layout.alignment: Qt.AlignVCenter }
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        RowLayout { spacing: root.s8; Layout.fillWidth: true
                            Text { text: root.batPresent ? root.batCap + "%" : "—"; color: root.fg; font.family: root.fontName; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignVCenter }
                            Text { text: root.batPresent ? "· " + root.batStatus.toLowerCase() : "no battery"; color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true; Layout.alignment: Qt.AlignVCenter }
                            Text { 
                                visible: root.batHealth < 95 && root.batPresent
                                text: "· health " + root.batHealth + "%"; 
                                color: root.batHealth < 70 ? root.red : root.yellow; 
                                font.family: root.fontName; font.pixelSize: 10; font.bold: true; 
                                Layout.alignment: Qt.AlignVCenter 
                            }
                        }
                        Text { text: root.batPresent ? root.batEstimate() : "desktop system"; color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true }
                    }
                    Rectangle {
                        visible: root.batPresent
                        Layout.preferredWidth: 100; Layout.preferredHeight: 22; radius: root.round; color: root.bgLight; clip: true
                        Rectangle { 
                            width: parent.width * root.batCap / 100; height: parent.height; radius: root.round
                            color: root.batAlert ? root.red : (root.batCharging || root.batIsFull) ? root.green : root.accent
                            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } } 
                        }
                        Text { anchors.centerIn: parent; text: root.batCap + "%"; color: root.fg; font.family: root.fontName; font.pixelSize: 10; font.bold: true }
                    }
                }
                Divider {}

                // Brightness row
                RowLayout {
                    Layout.fillWidth: true; spacing: root.s12
                    Rectangle { width: 28; height: 28; radius: root.round; color: root.accent+"22"
                        Text { anchors.centerIn: parent; text: root.iSun; font.family: root.fontName; font.pixelSize: 16; font.bold: true; color: root.accent }
                        Layout.alignment: Qt.AlignVCenter }
                    Slider {
                        id: desktopBriSlider
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        from: 1; to: 100; enabled: root.briAvail; value: root.brightness
                        background: Rectangle {
                            y: (parent.height - height) / 2; width: parent.width; height: 5; radius: 2; color: root.bgLight
                            Rectangle { 
                                width: desktopBriSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: root.accent
                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } 
                            }
                        }
                        handle: Rectangle {
                            x: desktopBriSlider.visualPosition * (desktopBriSlider.availableWidth - width)
                            y: (desktopBriSlider.availableHeight - height) / 2
                            width: 14; height: 14; radius: 7; color: root.fg; border.color: root.bg; border.width: 2
                            scale: desktopBriSlider.pressed ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        }
                        onMoved: { 
                            briSet.cmd = "set " + Math.round(value) + "%"; 
                            briSet.running = true; 
                        }
                    }
                    Text { 
                        text: root.briAvail ? root.brightness + "%" : "—"; 
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                        Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignVCenter 
                    }
                }

                Text { 
                    visible: root.briError !== ""; 
                    text: root.briError; 
                    color: root.red; 
                    font.family: root.fontName; font.pixelSize: 10; font.bold: true
                    wrapMode: Text.WordWrap; Layout.fillWidth: true 
                }

                Divider {}
                // Power — sleep/hibernate/idle/reboot/logout/shutdown from desktop icon
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: root.s8
                    columnSpacing: root.s8
                    Repeater {
                        model: root.powerEntries
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: root.round
                            color: ma.containsMouse ? root.bgHover : root.bgLight
                            border.color: ma.containsMouse ? root.borderHi : root.borderCol
                            border.width: 1
                            scale: ma.pressed ? 0.96 : 1
                            Behavior on color { ColorAnimation { duration: root.animFast } }
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: modelData.icon
                                    font.family: root.fontName; font.pixelSize: 16; font.bold: true
                                    color: index === 6 ? "#e06c75" : (index === 5 ? root.accent : root.fg)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.label
                                    font.family: root.fontName; font.pixelSize: 10; font.bold: true
                                    color: root.fg
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runPower(modelData)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: "desktop — brightness + battery + power"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                    }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }
            }
        }
    }

    // ══ CALENDAR ═══════════════════════════════════════════
    PanelWindow {
        id: calWin
        visible: root.openPanel === "cal"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        property date viewDate: clock.date
        function addMonths(d, n) { const x = new Date(d); x.setMonth(x.getMonth() + n); return x; }
        onVisibleChanged: if (visible) viewDate = clock.date

        readonly property var cells: {
            const y = viewDate.getFullYear(), m = viewDate.getMonth();
            const offset = (new Date(y, m, 1).getDay() + 6) % 7;
            const days = new Date(y, m + 1, 0).getDate();
            const out = [];
            for (let i = 0; i < offset; i++) out.push(null);
            for (let d = 1; d <= days; d++) out.push(d);
            return out;
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: calWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            id: calCard
            width: 310; height: 360
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 44
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: calWin.visible ? 1 : 0
            scale: calWin.visible ? 1 : 0.97
            y: calWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.s12
                spacing: root.s8
                PanelHeader { title: "CALENDAR" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s8
                    Rectangle { width: 24; height: 24; radius: root.round; color: maL.containsMouse ? root.bgLight : "transparent"
                        Text { anchors.centerIn: parent; text: "‹"; color: root.dim; font.family: root.fontName; font.pixelSize: 16; font.bold: true }
                        MouseArea { id: maL; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calWin.viewDate = calWin.addMonths(calWin.viewDate, -1) } }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(calWin.viewDate, "MMMM yyyy")
                        color: root.fg; font.family: root.fontName; font.pixelSize: 13; font.bold: true }
                    Rectangle { width: 24; height: 24; radius: root.round; color: maR.containsMouse ? root.bgLight : "transparent"
                        Text { anchors.centerIn: parent; text: "›"; color: root.dim; font.family: root.fontName; font.pixelSize: 16; font.bold: true }
                        MouseArea { id: maR; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calWin.viewDate = calWin.addMonths(calWin.viewDate, 1) } }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter; spacing: 2
                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Text { required property string modelData
                            width: 36; horizontalAlignment: Text.AlignHCenter
                            text: modelData; color: root.dim
                            font.family: root.fontName; font.pixelSize: 10; font.bold: true }
                    }
                }

                Grid {
                    Layout.alignment: Qt.AlignHCenter; columns: 7; spacing: 2
                    Repeater {
                        model: calWin.cells
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool isToday:
                                modelData !== null &&
                                calWin.viewDate.getFullYear() === clock.date.getFullYear() &&
                                calWin.viewDate.getMonth() === clock.date.getMonth() &&
                                modelData === clock.date.getDate()
                            width: 36; height: 28; radius: root.round
                            color: isToday ? root.accent : "transparent"
                            scale: isToday ? 1.02 : 1
                            Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutBack } }
                            Text { anchors.centerIn: parent
                                text: modelData === null ? "" : modelData
                                color: parent.isToday ? root.bg
                                     : index % 7 >= 5 ? root.dim : root.fg
                                font.family: root.fontName; font.pixelSize: 11; font.bold: parent.isToday }
                        }
                    }
                }

                Divider {}
                Text { Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Rectangle {
                        Layout.fillWidth: true; height: 28; radius: root.round; color: root.bgLight
                        border.color: root.borderCol; border.width: 1
                        Text { anchors.centerIn: parent; text: "Lower: next month →"; color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calWin.viewDate = calWin.addMonths(calWin.viewDate, 1) }
                    }
                    IconBtn { icon: root.iDown; onActivated: calWin.viewDate = calWin.addMonths(calWin.viewDate, 1) }
                }
            }
        }
    }

    // ══ WIFI ═══════════════════════════════════════════════
    PanelWindow {
        id: wifiWin
        visible: root.openPanel === "wifi"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) pwField.forceActiveFocus()

        Rectangle {
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: wifiWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 380; height: 460
            x: Math.max(10, parent.width - 109 - width / 2)
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: wifiWin.visible ? 1 : 0; scale: wifiWin.visible ? 1 : 0.97; y: wifiWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8
                PanelHeader { title: "WIFI" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { 
                            text: root.wifiEnabled ? 
                                (root.wifiSignal >= 0 ? "connected · " + root.wifiSignal + "%" : "not connected") : 
                                "wifi off"
                            color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true 
                        }
                        Text { 
                            text: root.networks.length + " networks nearby" + 
                                (root.downloadSpeed > 0 ? " · ↓" + Math.round(root.downloadSpeed) + "KB/s ↑" + Math.round(root.uploadSpeed) + "KB/s" : "")
                            color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true 
                        }
                    }
                    Rectangle {
                        width: 56; height: 24; radius: root.round; scale: wma.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: root.wifiEnabled ? root.accent : root.bgLight
                        Text { anchors.centerIn: parent; text: root.wifiEnabled ? "on" : "off"
                            color: root.wifiEnabled ? root.bg : root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true }
                        MouseArea { id: wma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { nmAction.cmd = root.wifiEnabled ? "radio wifi off" : "radio wifi on"; nmAction.running = true; } }
                    }
                }

                ColumnLayout {
                    visible: root.pendingSsid !== ""
                    Layout.fillWidth: true; spacing: root.s6
                    Divider {}
                    Text { text: "password for \"" + root.pendingSsid + "\""; color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s6
                        TextField {
                            id: pwField
                            Layout.fillWidth: true; echoMode: TextInput.Password
                            font.family: root.fontName; font.pixelSize: 12; font.bold: true; color: root.fg
                            background: Rectangle { radius: root.round; color: root.bgLight; border.color: pwField.activeFocus ? root.accent : root.borderCol; border.width: 1
                                Behavior on border.color { ColorAnimation { duration: root.animFast } } }
                            Keys.onReturnPressed: root.connectWifi(root.pendingSsid, pwField.text)
                            Keys.onEnterPressed:  root.connectWifi(root.pendingSsid, pwField.text)
                        }
                        Rectangle {
                            width: 70; height: 28; radius: root.round; color: root.accent; scale: pma.pressed ? 0.95 : 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Text { anchors.centerIn: parent; text: "connect"; color: root.bg; font.family: root.fontName; font.pixelSize: 11; font.bold: true }
                            MouseArea { id: pma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWifi(root.pendingSsid, pwField.text) }
                        }
                    }
                }

                Divider {}
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "networks"; color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }

                ScrollView {
                    id: wifiScroll
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ListView {
                        id: wifiList
                        spacing: 2; clip: true
                        model: root.networks
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width; height: 32; radius: root.round
                            color: ma.containsMouse ? root.bgHover : "transparent"
                            border.color: modelData.active ? root.accent : "transparent"; border.width: 1
                            opacity: 1
                            Component.onCompleted: { opacity = 0; y = 6; delayAnim.restart(); }

                            SequentialAnimation {
                                id: delayAnim
                                PauseAnimation { duration: index * 18 }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: parent; property: "y"; from: 6; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            Behavior on color { ColorAnimation { duration: root.animFast } }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: root.s8; anchors.rightMargin: root.s8
                                spacing: root.s8
                                Rectangle { 
                                    width: 32; height: 18; radius: 4
                                    color: modelData.active ? root.accent : root.bgLight
                                    Text { 
                                        anchors.centerIn: parent; text: modelData.signal + "%"
                                        color: modelData.active ? root.bg : root.dim
                                        font.family: root.fontName; font.pixelSize: 9; font.bold: modelData.active 
                                    }
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                                Text { 
                                    text: modelData.ssid; 
                                    color: modelData.active ? root.accent : root.fg
                                    font.family: root.fontName; font.pixelSize: 12; font.bold: modelData.active
                                    elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                                }
                                Text { 
                                    text: (modelData.sec !== "" && modelData.sec !== "--") ? root.iLock : ""; 
                                    font.family: root.fontName; color: root.dim; font.pixelSize: 11; font.bold: true
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                                Text { 
                                    text: modelData.active ? root.iCheck : "";
                                    font.family: root.fontName; color: root.accent; font.pixelSize: 11; font.bold: true
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.active) return;
                                    const secured = modelData.sec !== "" && modelData.sec !== "--";
                                    if (secured) { root.pendingSsid = modelData.ssid; pwField.text = ""; }
                                    else root.connectWifi(modelData.ssid, "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ══ BLUETOOTH ═════════════════════════════════════════
    PanelWindow {
        id: btWin
        visible: root.openPanel === "bt"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: btWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 340; height: 400
            x: Math.max(10, parent.width - 67 - width / 2)
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: btWin.visible ? 1 : 0; scale: btWin.visible ? 1 : 0.97; y: btWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8
                PanelHeader { title: "BLUETOOTH" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: root.btPowered ? "Bluetooth on" : "Bluetooth off"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                    }
                    Rectangle {
                        width: 56; height: 24; radius: root.round; scale: bma2.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: root.btPowered ? root.accent : root.bgLight
                        Text { anchors.centerIn: parent; text: root.btPowered ? "on" : "off"
                            color: root.btPowered ? root.bg : root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true }
                        MouseArea { id: bma2; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { btAction.cmd = root.btPowered ? "power off" : "power on"; btAction.running = true; } }
                    }
                }

                Text { 
                    visible: root.btDevices.length === 0; 
                    text: "no paired devices"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        id: btList
                        spacing: 2; model: root.btDevices; clip: true
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true; width: ListView.view.width; height: 32; radius: root.round
                            color: ma.containsMouse ? root.bgHover : "transparent"
                            Behavior on color { ColorAnimation { duration: root.animFast } }

                            Component.onCompleted: { opacity = 0; y = 6; delAnim.restart(); }
                            SequentialAnimation { 
                                id: delAnim
                                PauseAnimation { duration: index*30 }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property: "opacity"; from:0; to:1; duration:200; easing.type:Easing.OutCubic }
                                    NumberAnimation { target: parent; property: "y"; from:6; to:0; duration:200; easing.type:Easing.OutCubic }
                                } 
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: root.s8; anchors.rightMargin: root.s8; spacing: root.s8
                                Rectangle { 
                                    width: 8; height: 8; radius: 4
                                    color: modelData.connected ? root.green : root.dim
                                    Layout.alignment: Qt.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: root.animFast } } 
                                }
                                Text { 
                                    text: modelData.name; color: root.fg; font.family: root.fontName
                                    font.pixelSize: 12; font.bold: true; elide: Text.ElideRight
                                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                                }
                                Rectangle { 
                                    width: 68; height: 22; radius: root.round
                                    color: modelData.connected ? root.bgLight : root.accent
                                    Text { 
                                        anchors.centerIn: parent
                                        text: modelData.connected ? "disconnect" : "connect"
                                        color: modelData.connected ? root.dim : root.bg
                                        font.family: root.fontName; font.pixelSize: 10; font.bold: !modelData.connected 
                                    }
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    btAction.cmd = (modelData.connected ? "disconnect " : "connect ") + modelData.mac
                                    btAction.running = true; 
                                }
                            }
                        }
                    }
                }

                Divider {}
                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: "pair new devices with bluetoothctl once —\nthey appear here after"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        wrapMode: Text.WordWrap; Layout.fillWidth: true 
                    }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }
            }
        }
    }

    // ══ VOLUME ════════════════════════════════════════════
    PanelWindow {
        id: volWin
        visible: root.openPanel === "vol"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: volWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 320; height: 180
            x: Math.max(10, parent.width - 151 - width / 2)
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: volWin.visible ? 1 : 0; scale: volWin.visible ? 1 : 0.97; y: volWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s12
                PanelHeader { title: "VOLUME" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s12
                    Rectangle { 
                        width: 28; height: 28; radius: root.round
                        color: root.volMuted ? root.bgLight : root.accent+"22"
                        Text { 
                            anchors.centerIn: parent; text: root.volIcon
                            font.family: root.fontName; font.pixelSize: 16; font.bold: true
                            color: root.volMuted ? root.dim : root.accent 
                        }
                        Layout.alignment: Qt.AlignVCenter 
                    }
                    Slider {
                        id: volSlider
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        from: 0; to: 1; value: root.volLevel
                        background: Rectangle {
                            y: (parent.height - height) / 2
                            width: parent.width; height: 5; radius: 2; color: root.bgLight
                            Rectangle { 
                                width: volSlider.visualPosition * parent.width; height: parent.height; radius: 2
                                color: root.volMuted ? root.dim : root.accent
                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } 
                            }
                        }
                        handle: Rectangle {
                            x: volSlider.visualPosition * (volSlider.availableWidth - width)
                            y: (volSlider.availableHeight - height) / 2
                            width: 14; height: 14; radius: 7; color: root.fg; border.color: root.bg; border.width: 2
                            scale: volSlider.pressed ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        }
                        onMoved: root.setVolume(value)
                    }
                    Text { 
                        text: Math.round(root.volLevel * 100) + "%"
                        color: root.volMuted ? root.dim : root.fg
                        font.family: root.fontName; font.pixelSize: 12; font.bold: true
                        Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignVCenter 
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: root.volMuted ? "muted" : "volume · " + Math.round(root.volLevel*100) + "%"
                        color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                    }
                    Rectangle {
                        width: 60; height: 26; radius: root.round; scale: vma.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: root.volMuted ? root.red : root.bgLight
                        Text { 
                            anchors.centerIn: parent; text: root.volMuted ? "unmute" : "mute"
                            color: root.volMuted ? "white" : root.dim
                            font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                        }
                        MouseArea { 
                            id: vma
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.pwReady && root.pwSink.audio) root.pwSink.audio.muted = !root.volMuted;
                                else { 
                                    volProc.cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null"
                                    volProc.running = true; 
                                    volRefresh.running = true; 
                                }
                            } 
                        }
                    }
                    IconBtn { icon: root.iDown; onActivated: root.adjVolume(-0.05) }
                }

                Text { 
                    text: "scroll · lower → -5%  ·  upper → +5%"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                    Layout.alignment: Qt.AlignHCenter 
                }
            }
        }
    }

    // ══ BRIGHTNESS ════════════════════════════════════════
    PanelWindow {
        id: briWin
        visible: root.openPanel === "bri"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: briWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 320; height: 190
            x: Math.max(10, parent.width - 25 - width / 2)
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: briWin.visible ? 1 : 0; scale: briWin.visible ? 1 : 0.97; y: briWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s12
                PanelHeader { title: "BRIGHTNESS" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s12
                    Rectangle { 
                        width: 28; height: 28; radius: root.round; color: root.accent+"22"
                        Text { 
                            anchors.centerIn: parent; text: root.iSun
                            font.family: root.fontName; font.pixelSize: 16; font.bold: true; color: root.accent 
                        }
                        Layout.alignment: Qt.AlignVCenter 
                    }
                    Slider {
                        id: briSlider
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        from: 1; to: 100; enabled: root.briAvail
                        Component.onCompleted: value = root.brightness
                        background: Rectangle {
                            y: (parent.height - height) / 2
                            width: parent.width; height: 5; radius: 2; color: root.bgLight
                            Rectangle { 
                                width: briSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: root.accent
                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } 
                            }
                        }
                        handle: Rectangle {
                            x: briSlider.visualPosition * (briSlider.availableWidth - width)
                            y: (briSlider.availableHeight - height) / 2
                            width: 14; height: 14; radius: 7; color: root.fg; border.color: root.bg; border.width: 2
                            scale: briSlider.pressed ? 1.2 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        }
                        onMoved: { 
                            briSet.cmd = "set " + Math.round(value) + "%"; 
                            briSet.running = true; 
                        }
                    }
                    Text { 
                        text: root.briAvail ? root.brightness + "%" : "—"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                        Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; Layout.alignment: Qt.AlignVCenter 
                    }
                }

                Text {
                    visible: root.briError !== ""
                    text: root.briError
                    color: root.red; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: "scroll sun → ±5%  ·  lower → -5%"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        Layout.fillWidth: true 
                    }
                    IconBtn { 
                        icon: root.iDown
                        onActivated: { 
                            briSet.cmd = "set 5%-"; 
                            briSet.running = true; 
                        } 
                    }
                }
            }
        }
    }

    // ══ BATTERY ═══════════════════════════════════════════
    PanelWindow {
        id: batWin
        visible: root.openPanel === "bat"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: batWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 320; height: 200
            x: Math.max(10, parent.width - 151 - width / 2)
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: batWin.visible ? 1 : 0; scale: batWin.visible ? 1 : 0.97; y: batWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s12
                PanelHeader { title: "BATTERY" }
                Divider {}

                Text { 
                    visible: !root.batPresent
                    text: "no battery detected (desktop system?)"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                }

                Rectangle {
                    visible: root.batPresent
                    Layout.fillWidth: true; height: 22; radius: root.round; color: root.bgLight; clip: true
                    Rectangle {
                        width: parent.width * root.batCap / 100
                        height: parent.height; radius: root.round
                        color: root.batAlert ? root.red : (root.batCharging || root.batIsFull) ? root.green : root.accent
                        Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: root.animNorm } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.batCap + "%"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                    }
                }

                Text {
                    visible: root.batPresent
                    text: root.batStatus.toLowerCase() + 
                        (root.batEstimate() !== "" ? " · " + root.batEstimate() : "") + 
                        (root.batAlert ? "  — low battery" : "") +
                        (root.batHealth < 95 ? " · health " + root.batHealth + "%" : "")
                    color: root.batAlert ? root.red : (root.batHealth < 70 ? root.red : root.dim)
                    font.family: root.fontName; font.pixelSize: 11; font.bold: true
                }

                RowLayout {
                    visible: root.batPresent
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: "Battery Health: " + root.batHealth + "%"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true 
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 4; radius: 2; color: root.bgLight
                        Rectangle {
                            width: parent.width * root.batHealth / 100
                            height: parent.height; radius: 2
                            color: root.batHealth > 80 ? root.green : (root.batHealth > 60 ? root.yellow : root.red)
                        }
                    }
                }
            }
        }
    }

    // ══ NOTIFICATIONS ══════════════════════════════════════
    PanelWindow {
        id: notifWin
        visible: root.openPanel === "notif"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: notifWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 380; height: 460
            x: parent.width / 2 - width / 2 + 60
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: notifWin.visible ? 1 : 0; scale: notifWin.visible ? 1 : 0.97; y: notifWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8
                PanelHeader { title: "NOTIFICATIONS" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Rectangle { 
                        width: 28; height: 28; radius: root.round; color: root.dnd ? root.accent+"22" : root.bgLight
                        Text { 
                            anchors.centerIn: parent; text: root.iMoon
                            font.family: root.fontName; font.pixelSize: 13; font.bold: true
                            color: root.dnd ? root.accent : root.dim 
                        }
                        Layout.alignment: Qt.AlignVCenter 
                    }
                    Text { 
                        text: "do not disturb"; 
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                    }
                    Rectangle {
                        width: 56; height: 24; radius: root.round; scale: dma.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: root.dnd ? root.accent : root.bgLight
                        Text { 
                            anchors.centerIn: parent; text: root.dnd ? "on" : "off"
                            color: root.dnd ? root.bg : root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                        }
                        MouseArea { 
                            id: dma
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.dnd = !root.dnd 
                        }
                    }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }

                Text { 
                    visible: root.notifs.length === 0; 
                    text: "no notifications"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                    Layout.alignment: Qt.AlignHCenter 
                }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        id: notifList
                        spacing: root.s4; clip: true; model: root.notifs
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width
                            height: ncol.implicitHeight + 14
                            radius: root.round
                            color: root.bgLight
                            border.color: root.borderCol; border.width: 1
                            opacity: 1

                            Component.onCompleted: { opacity=0; y=8; delAnim.restart(); }
                            SequentialAnimation { 
                                id: delAnim
                                PauseAnimation { duration: index*40 }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property: "opacity"; from:0; to:1; duration:260; easing.type:Easing.OutCubic }
                                    NumberAnimation { target: parent; property: "y"; from:8; to:0; duration:260; easing.type:Easing.OutCubic }
                                } 
                            }

                            ColumnLayout {
                                id: ncol
                                anchors.fill: parent; anchors.margins: root.s8; spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true; spacing: root.s8
                                    Text { 
                                        text: modelData.title; 
                                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                                    }
                                    Rectangle { 
                                        width: 20; height: 20; radius: 10
                                        color: xma.containsMouse ? root.red+"22" : "transparent"
                                        Text { 
                                            anchors.centerIn: parent; text: "×"
                                            color: xma.containsMouse ? root.red : root.dim
                                            font.family: root.fontName; font.pixelSize: 13; font.bold: true 
                                        }
                                        MouseArea { 
                                            id: xma
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.dismiss(modelData) 
                                        }
                                        Layout.alignment: Qt.AlignVCenter 
                                    }
                                }
                                Text { 
                                    visible: modelData.body !== ""; text: modelData.body
                                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true 
                                }
                                Text { 
                                    text: modelData.app + (modelData.count > 1 ? " (" + modelData.count + ")" : "")
                                    color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                                    opacity: 0.7 
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: root.round; color: root.bgLight; scale: cma.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Text { 
                        anchors.centerIn: parent; text: "clear all"; 
                        color: root.fg; font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                    }
                    MouseArea { 
                        id: cma
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearNotifs() 
                    }
                }
            }
        }
    }

    // ══ REMINDERS ══════════════════════════════════════════
    PanelWindow {
        id: remWin
        visible: root.openPanel === "rem"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) remText.forceActiveFocus()

        Rectangle { 
            anchors.fill: parent; anchors.topMargin: 42; color: "#77000000"
            opacity: remWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() } 
        }

        Rectangle {
            width: 400; height: 440
            x: parent.width / 2 - width / 2 + 100
            anchors.top: parent.top; anchors.topMargin: 44
            radius: root.round; color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: remWin.visible ? 1 : 0; scale: remWin.visible ? 1 : 0.97; y: remWin.visible ? 0 : -10
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8
                PanelHeader { title: "REMINDERS" }
                Divider {}

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s6
                    TextField {
                        id: remText
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        font.family: root.fontName; font.pixelSize: 12; font.bold: true; color: root.fg
                        placeholderText: "remind me to…"; placeholderTextColor: root.dim
                        leftPadding: 10; topPadding: 8; bottomPadding: 8
                        background: Rectangle { 
                            radius: root.round; color: root.bgLight
                            border.color: remText.activeFocus ? root.accent : root.borderCol; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: root.animFast } } 
                        }
                        Keys.onReturnPressed: root.addReminder(remText.text, remWhen.text)
                        Keys.onEnterPressed:  root.addReminder(remText.text, remWhen.text)
                    }
                    TextField {
                        id: remWhen
                        Layout.preferredWidth: 76; Layout.alignment: Qt.AlignVCenter
                        font.family: root.fontName; font.pixelSize: 12; font.bold: true; color: root.fg
                        placeholderText: "when"; placeholderTextColor: root.dim
                        leftPadding: 10; topPadding: 8; bottomPadding: 8
                        background: Rectangle { 
                            radius: root.round; color: root.bgLight
                            border.color: remWhen.activeFocus ? root.accent : root.borderCol; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: root.animFast } } 
                        }
                        Keys.onReturnPressed: root.addReminder(remText.text, remWhen.text)
                        Keys.onEnterPressed:  root.addReminder(remText.text, remWhen.text)
                    }
                    Rectangle {
                        width: 52; height: 30; radius: root.round; color: root.accent; scale: rma.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Text { 
                            anchors.centerIn: parent; text: "set"
                            color: root.bg; font.family: root.fontName; font.pixelSize: 11; font.bold: true 
                        }
                        MouseArea { 
                            id: rma
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.addReminder(remText.text, remWhen.text) 
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Text { 
                    visible: root.remHint !== ""; text: root.remHint
                    color: root.red; font.family: root.fontName; font.pixelSize: 10; font.bold: true 
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    Text { 
                        text: "pending"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                        Layout.fillWidth: true 
                    }
                    Text { 
                        text: root.reminders.length + " scheduled"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        opacity: 0.8 
                    }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }

                Text { 
                    visible: root.reminders.length === 0; 
                    text: "nothing scheduled"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                    Layout.alignment: Qt.AlignHCenter 
                }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        id: remList
                        spacing: root.s4; clip: true; model: root.reminders
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width; height: 36; radius: root.round
                            color: root.bgLight; border.color: root.borderCol; border.width: 1

                            Component.onCompleted: { opacity=0; y=6; a.restart(); }
                            SequentialAnimation { 
                                id: a
                                PauseAnimation { duration: index*30 }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property:"opacity"; from:0; to:1; duration:220; easing.type:Easing.OutCubic }
                                    NumberAnimation { target: parent; property:"y"; from:6; to:0; duration:220; easing.type:Easing.OutCubic }
                                } 
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: root.s8
                                Rectangle { 
                                    width: 66; height: 20; radius: 4; color: root.accent+"18"; Layout.alignment: Qt.AlignVCenter
                                    Text { 
                                        anchors.centerIn: parent
                                        text: root.fmtLeftAt(modelData.when, root.nowTick)
                                        color: root.accent; font.family: root.fontName; font.pixelSize: 10; font.bold: true 
                                    } 
                                }
                                Text { 
                                    text: modelData.text
                                    color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                                    elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter 
                                }
                                Rectangle { 
                                    width: 20; height: 20; radius: 10
                                    color: dma.containsMouse ? root.red+"22" : "transparent"
                                    Text { 
                                        anchors.centerIn: parent; text: "×"
                                        color: dma.containsMouse ? root.red : root.dim
                                        font.family: root.fontName; font.pixelSize: 13; font.bold: true 
                                    }
                                    MouseArea { 
                                        id: dma
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.delReminder(modelData) 
                                    }
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                            }
                        }
                    }
                }

                Text { 
                    text: "when: 15m · 45m · 1h · 1h30 · 14:30 · tomorrow 09:00 — Lower scrolls ↓"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                    wrapMode: Text.WordWrap; Layout.fillWidth: true 
                }
            }
        }
    }

    // ══ APP LAUNCHER ═══════════════════════════════════════
    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        readonly property var results: {
            const q = search.text.toLowerCase().trim();
            const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
            const list = q ? all.filter(e =>
                (e.name || "").toLowerCase().includes(q) ||
                (e.genericName || "").toLowerCase().includes(q) ||
                (e.comment || "").toLowerCase().includes(q) ||
                (e.id || "").toLowerCase().includes(q)) : all;
            return list.sort((a, b) => {
                const an = (a.name||"").toLowerCase(), bn=(b.name||"").toLowerCase();
                const ap = q && an.startsWith(q) ? 0 : 1, bp = q && bn.startsWith(q) ? 0 : 1;
                if (ap !== bp) return ap - bp;
                return an.localeCompare(bn);
            });
        }

        function launch(e) { 
            if (!e) return; 
            e.execute(); 
            root.launcherOpen = false;
            // Add to recent
            root.recentApps = [e.id, ...root.recentApps.filter(id => id !== e.id)].slice(0, 10);
            log("Launched: " + e.name);
        }

        onVisibleChanged: if (visible) { 
            search.text = ""; 
            card2.sel = 0; 
            search.forceActiveFocus();
            // Load favorites
            const favs = [];
            for (const app of DesktopEntries.applications.values) {
                if (root.favorites.includes(app.id)) favs.push(app);
            }
            // You could filter/sort these differently
        }

        Rectangle {
            anchors.fill: parent; color: "#88000000"
            opacity: launcher.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.launcherOpen = false }
        }

        Rectangle {
            id: card2
            property int sel: 0
            width: 520; height: 460
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 120
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: launcher.visible ? 1 : 0; scale: launcher.visible ? 1 : 0.96; y: launcher.visible ? 0 : -16
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8

                RowLayout {
                    Layout.fillWidth: true; spacing: root.s8
                    TextField {
                        id: search
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        font.family: root.fontName; font.pixelSize: 13; font.bold: true; color: root.fg
                        placeholderText: "search…  (" + launcher.results.length + " apps)"; placeholderTextColor: root.dim
                        leftPadding: 12; topPadding: 10; bottomPadding: 10
                        background: Rectangle { 
                            radius: root.round; color: root.bgLight
                            border.color: search.activeFocus ? root.accent : root.borderCol; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: root.animFast } } 
                        }
                        onTextChanged: card2.sel = 0
                        Keys.onEscapePressed: root.launcherOpen = false
                        Keys.onDownPressed: card2.sel = Math.min(card2.sel + 1, launcher.results.length - 1)
                        Keys.onUpPressed:   card2.sel = Math.max(card2.sel - 1, 0)
                        Keys.onReturnPressed: launcher.launch(launcher.results[card2.sel])
                        Keys.onEnterPressed:  launcher.launch(launcher.results[card2.sel])
                    }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }

                Text { 
                    visible: launcher.results.length === 0; 
                    text: "no results"; 
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11; font.bold: true
                    Layout.alignment: Qt.AlignHCenter 
                }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        id: appList
                        spacing: 2; clip: true; model: launcher.results
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: appList.width; height: 40; radius: root.round
                            color: index === card2.sel || ma.containsMouse ? root.bgHover : "transparent"
                            border.color: index === card2.sel ? root.borderHi : "transparent"; border.width: 1
                            scale: index === card2.sel ? 1.01 : 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Component.onCompleted: { opacity=0; y=8; anim.restart(); }
                            SequentialAnimation { 
                                id: anim
                                PauseAnimation { duration: Math.min(index*12, 120) }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property:"opacity"; from:0; to:1; duration:240; easing.type:Easing.OutCubic }
                                    NumberAnimation { target: parent; property:"y"; from:8; to:0; duration:240; easing.type:Easing.OutCubic }
                                } 
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                                IconImage { 
                                    source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                    width: 24; height: 24; smooth: true; Layout.alignment: Qt.AlignVCenter 
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1; Layout.alignment: Qt.AlignVCenter
                                    Text { 
                                        text: modelData.name
                                        color: root.fg; font.family: root.fontName; font.pixelSize: 12
                                        font.bold: index===card2.sel; elide: Text.ElideRight; Layout.fillWidth: true 
                                    }
                                    Text { 
                                        visible: modelData.genericName && modelData.genericName !== modelData.name
                                        text: modelData.genericName
                                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true 
                                    }
                                }
                                Text { 
                                    visible: root.favorites.includes(modelData.id)
                                    text: "★"; color: root.yellow; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: launcher.launch(modelData)
                                onEntered: card2.sel = index
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { 
                        text: "↵ launch  ·  ↑↓ navigate  ·  Lower ↓ scroll  ·  ★ favorites"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        Layout.alignment: Qt.AlignVCenter 
                    }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: appList.count + " apps"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        opacity: 0.8; Layout.alignment: Qt.AlignVCenter 
                    }
                }
            }
        }
    }

    // ══ POWER MENU ═════════════════════════════════════════
    PanelWindow {
        id: powerWin
        visible: root.powerOpen
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        function doIdx(i) { root.runPower(root.powerEntries[i]); }
        onVisibleChanged: if (visible) { root.powerSel = 0; powerList.forceActiveFocus(); }

        Rectangle {
            anchors.fill: parent; color: "#88000000"
            opacity: powerWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animNorm; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.powerOpen = false }
        }

        Rectangle {
            id: powerCard
            width: 440; height: 440
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 120
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: powerWin.visible ? 1 : 0; scale: powerWin.visible ? 1 : 0.96; y: powerWin.visible ? 0 : -16
            Behavior on opacity { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: root.animPanel; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s12; spacing: root.s8
                PanelHeader { title: "POWER" }
                Divider {}

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    ListView {
                        id: powerList
                        spacing: root.s4; clip: true; model: root.powerEntries; currentIndex: root.powerSel
                        highlightMoveDuration: 0; highlightFollowsCurrentItem: true
                        highlight: Rectangle { color: root.bgHover; radius: root.round; border.color: root.borderHi; border.width: 1 }
                        focus: true
                        Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        Keys.onDownPressed: root.powerSel = Math.min(root.powerSel + 1, root.powerEntries.length - 1)
                        Keys.onUpPressed:   root.powerSel = Math.max(root.powerSel - 1, 0)
                        Keys.onReturnPressed: powerWin.doIdx(root.powerSel)
                        Keys.onEnterPressed:  powerWin.doIdx(root.powerSel)

                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: powerList.width; height: 54; radius: root.round
                            color: "transparent"
                            scale: index === root.powerSel ? 1.01 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                            Component.onCompleted: { opacity=0; y=8; pa.restart(); }
                            SequentialAnimation { 
                                id: pa
                                PauseAnimation { duration: index*30 }
                                ParallelAnimation {
                                    NumberAnimation { target: parent; property:"opacity"; from:0; to:1; duration:260; easing.type:Easing.OutCubic }
                                    NumberAnimation { target: parent; property:"y"; from:8; to:0; duration:260; easing.type:Easing.OutCubic }
                                } 
                            }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: root.s12
                                Rectangle {
                                    width: 36; height: 36; radius: root.round; color: index === 5 ? "#3d2a2e" : root.bgLight
                                    scale: ma.containsMouse ? 1.05 : 1
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                    Text { 
                                        anchors.centerIn: parent; text: modelData.icon
                                        color: index === 5 ? "#e06c75" : (index === 4 ? root.accent : root.fg)
                                        font.family: root.fontName; font.pixelSize: 16; font.bold: true 
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2; Layout.alignment: Qt.AlignVCenter
                                    Text { 
                                        text: modelData.label; 
                                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; font.bold: true 
                                    }
                                    Text { 
                                        text: modelData.desc; 
                                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true 
                                    }
                                }
                                Text { 
                                    visible: index === root.powerSel; text: "↵"
                                    color: root.dim; font.family: root.fontName; font.pixelSize: 12; font.bold: true
                                    Layout.alignment: Qt.AlignVCenter 
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: root.powerSel = index
                                onClicked: powerWin.doIdx(index)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { 
                        text: "↑↓ navigate · Lower ↓ scroll · ↵ select"; 
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10; font.bold: true
                        Layout.alignment: Qt.AlignVCenter 
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn { icon: root.iDown; onActivated: root.scrollNextSection() }
                }
            }
        }
    }
}
