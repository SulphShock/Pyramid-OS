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

ShellRoot {
    id: root

    // ── behaviour ──────────────────────────────────────────
    property bool useWalker: false
    property bool launcherOpen: false
    property bool powerOpen: false
    property string openPanel: ""   // "cal" | "wifi" | "bt" | "bri" | "bat" | "notif" | "rem"

    readonly property int round: 5   // 5px rounding — everywhere, always

    // ══ SOLITUDE PALETTE — paste exact theme hexes here ════
    readonly property color bg:        "#12141f"
    readonly property color bgLight:   "#1e2233"
    readonly property color borderCol: "#2b3046"
    readonly property color fg:        "#c3c8dd"
    readonly property color dim:       "#767da0"
    readonly property color accent:    "#96a7f2"
    readonly property color green:     "#9dc6a8"
    readonly property color red:       "#d0808a"
    // ═══════════════════════════════════════════════════════
    readonly property string fontName: "JetBrainsMono Nerd Font"

    // ── icons (escape sequences — survive copy-paste) ──────
    readonly property string iLaunch: "\uf135"
    readonly property string iWifi:   "\uf1eb"
    readonly property string iBt:     "\uf294"
    readonly property string iSun:    "\uf185"
    readonly property string iBell:   "\uf0f3"
    readonly property string iClock:  "\uf017"
    readonly property string iMoon:   "\uf186"
    readonly property string iLock:   "\uf023"
    readonly property string iCheck:  "\uf00c"
    readonly property string iPower:  "\uf011"
    readonly property string iReboot: "\uf021"
    readonly property string iSleep:  "\uf186"
    readonly property string iLogout: "\uf08b"
    readonly property string iHibernate: "\uf2db"

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
    // battery
    property bool batPresent: false
    property int  batCap: 0
    property string batStatus: ""
    property string batFamily: ""        // "E" (Wh) or "C" (Ah)
    property real  batNow: 0
    property real  batFull: 0
    property real  batRate: 0
    property bool batAlerted: false
    // notification queue (reminders + low battery)
    property var notifQueue: []

    // ── battery derived ────────────────────────────────────
    readonly property bool batCharging: batStatus.indexOf("Charg") === 0
    readonly property bool batIsFull:   batStatus.indexOf("Full") === 0
    readonly property bool batAlert: batPresent && !batCharging && !batIsFull && batCap > 0 && batCap < 15
    readonly property string batIcon:
        !batPresent   ? "" :
        batCharging   ? "\uf0e7" :
        batCap >= 90  ? "\uf240" :
        batCap >= 60  ? "\uf241" :
        batCap >= 30  ? "\uf242" :
        batCap >= 15  ? "\uf243" : "\uf244"

    function batEstimate() {
        if (!batPresent || batRate <= 0 || batNow <= 0) return "";
        // energy family: Wh vs µW → ×1e6 · charge family: µAh vs µA → consistent
        const f = batFamily === "E" ? 1e6 : 1;
        const mins = (batCharging ? (batFull - batNow) / batRate
                                  : batNow / batRate) * 60 * f;
        if (!isFinite(mins) || mins <= 0 || mins > 6000) return "";
        const h = Math.floor(mins / 60), m = Math.round(mins % 60);
        const t = (h > 0 ? h + "h " : "") + m + "m";
        return batCharging ? "~" + t + " to full" : "~" + t + " left";
    }

    function closePanel() { root.openPanel = ""; }
    function togglePanel(name) { root.openPanel = (root.openPanel === name ? "" : name); }
    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }
    function connectWifi(ssid, pass) {
        nmAction.cmd = "nmcli device wifi connect " + shq(ssid) +
                       (pass ? " password " + shq(pass) : "");
        nmAction.running = true;
        root.pendingSsid = "";
    }
    function dismiss(n) { n.obj.close(); root.notifs = root.notifs.filter(x => x !== n); }
    function clearNotifs() {
        for (const n of root.notifs) n.obj.close();
        root.notifs = [];
    }
    function pushNotify(title, body) {
        root.notifQueue = root.notifQueue.concat([{ t: title, b: body }]);
        pumpNotify();
    }
    function pumpNotify() {
        if (root.notifQueue.length === 0 || notifyProc.running) return;
        const n = root.notifQueue[0];
        root.notifQueue = root.notifQueue.slice(1);
        notifyProc.cmd = "notify-send -a Shell " + shq(n.t) + " " + shq(n.b);
        notifyProc.running = true;
    }

    // ── reminder helpers ───────────────────────────────────
    function parseWhen(s) {
        s = s.trim().toLowerCase();
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
        if (!when) { root.remHint = "when: 15m · 1h30 · 14:30"; return; }
        root.reminders = root.reminders.concat([{ when: when, text: t }])
                             .sort((a, b) => a.when - b.when);
        saveReminders();
        root.remHint = "";
        remText.text = ""; remWhen.text = "";
    }
    function delReminder(r) {
        root.reminders = root.reminders.filter(x => x !== r);
        saveReminders();
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.launcherOpen = !root.launcherOpen;
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.powerOpen = !root.powerOpen;
        }
    }

    // ══ NOTIFICATIONS ══════════════════════════════════════
    NotificationServer {
        id: notifServer
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: notification => {
            if (root.dnd) { notification.close(); return; }
            const ms = notification.expireTimeout;
            root.notifs = root.notifs.concat([{
                obj: notification,
                title: notification.summary,
                body: notification.body,
                app: notification.appName,
                expires: ms > 0 ? Date.now() + ms : 0
            }]);
        }
    }

    Timer { interval: 1000; repeat: true; running: root.notifs.length > 0
            onTriggered: {
                const now = Date.now();
                const keep = root.notifs.filter(n => n.expires === 0 || n.expires > now);
                if (keep.length !== root.notifs.length) root.notifs = keep;
            } }

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
                } catch (e) { }
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
        stdout: StdioCollector { onStreamFinished: root.pumpNotify() }
    }
    Component.onCompleted: { remLoadProc.running = true; batProc.running = true }

    Timer { interval: 5000; repeat: true; running: true
            onTriggered: {
                root.nowTick = Date.now();
                const due = root.reminders.filter(r => r.when <= Date.now());
                if (due.length) {
                    for (const r of due) root.pushNotify("Reminder", r.text);
                    root.reminders = root.reminders.filter(r => r.when > Date.now());
                    saveReminders();
                }
                // low-battery warning — fires once per discharge below 15%
                if (root.batAlert && !root.batAlerted) {
                    root.batAlerted = true;
                    root.pushNotify("Battery", root.batCap + "% remaining — plug in soon");
                } else if (!root.batAlert) {
                    root.batAlerted = false;
                }
            } }

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
            }
        }
    }

    // ══ BLUETOOTH ══════════════════════════════════════════
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
        stdout: StdioCollector { onStreamFinished: { btStatus.running = true; btDevicesProc.running = true; } }
    }

    // ══ WIFI ═══════════════════════════════════════════════
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
        stdout: StdioCollector { onStreamFinished: { wifiStatus.running = true; wifiScan.running = true; } }
    }

    // ══ BRIGHTNESS (debounced set, real error surfacing) ═══
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
            }
        }
    }
    Process {
        id: briSet
        property string cmd: ""
        command: ["sh", "-c", "brightnessctl " + cmd]
        stdout: StdioCollector { onStreamFinished: briProc.running = true }
        stderr: StdioCollector { onStreamFinished: root.briError = text.trim() }
    }
    Timer { id: briDebounce; interval: 120; repeat: false
            onTriggered: { briSet.cmd = "set " + briPending + "%"; briSet.running = true } }
    property int briPending: 0

    // ══ poll timers ════════════════════════════════════════
    Timer { interval: 5000; triggeredOnStart: true; repeat: true; running: true
            onTriggered: { btStatus.running = true; wifiStatus.running = true;
                           briProc.running = true; batProc.running = true } }
    Timer { interval: 4000; triggeredOnStart: true; repeat: true; running: root.openPanel === "bt"
            onTriggered: btDevicesProc.running = true }
    Timer { interval: 6000; triggeredOnStart: true; repeat: true; running: root.openPanel === "wifi"
            onTriggered: wifiScan.running = true }

    // ══ THE BAR ════════════════════════════════════════════
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        margins { top: 5; left: 8; right: 8 }
        implicitHeight: 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: root.round
            color: root.bg
            border.color: root.borderCol
            border.width: 1

            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "h:mm ap")
                color: root.fg
                font.family: root.fontName; font.pixelSize: 12
                z: 1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 4

                IconBtn {
                    icon: root.iLaunch
                    onActivated: root.useWalker ? Hyprland.dispatch("exec", "walker")
                                                : root.launcherOpen = !root.launcherOpen
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 3
                    Rectangle {
                        width: notifCount.width + 10; height: 16; radius: 3
                        color: root.notifs.length > 0 ? root.accent : "transparent"
                        visible: root.notifs.length > 0
                        Text {
                            id: notifCount
                            anchors.centerIn: parent
                            text: root.notifs.length
                            font.family: root.fontName; font.pixelSize: 10
                            color: root.bg
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("notif")
                        }
                    }
                    IconBtn {
                        icon: root.iBell
                        dimmed: root.dnd && root.notifs.length === 0
                        onActivated: root.togglePanel("notif")
                    }
                    IconBtn {
                        icon: root.iWifi
                        dimmed: !root.wifiEnabled
                        accented: root.wifiEnabled && root.wifiSignal >= 0
                        onActivated: root.togglePanel("wifi")
                    }
                    IconBtn {
                        icon: root.iBt
                        dimmed: !root.btPowered
                        accented: root.btConnected > 0
                        onActivated: root.togglePanel("bt")
                    }
                    IconBtn {
                        icon: root.iSun
                        onActivated: root.togglePanel("bri")
                        onWheeled: d => {
                            briSet.cmd = d > 0 ? "set +5%" : "set 5%-";
                            briSet.running = true;
                        }
                    }
                }
            }
        }
    }

    // ══ CALENDAR — centered ══════════════════════════════════
    PanelWindow {
        id: calWin
        visible: root.openPanel === "cal"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

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
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 310; height: 340
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: calWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelHeader { title: "CALENDAR" }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "‹"; color: root.dim; font.family: root.fontName; font.pixelSize: 16
                        MouseArea { anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calWin.viewDate = calWin.addMonths(calWin.viewDate, -1) } }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDateTime(calWin.viewDate, "MMMM yyyy")
                        color: root.fg; font.family: root.fontName; font.pixelSize: 13 }
                    Text { text: "›"; color: root.dim; font.family: root.fontName; font.pixelSize: 16
                        MouseArea { anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calWin.viewDate = calWin.addMonths(calWin.viewDate, 1) } }
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter; spacing: 2
                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Text { required property string modelData
                            width: 36; horizontalAlignment: Text.AlignHCenter
                            text: modelData; color: root.dim
                            font.family: root.fontName; font.pixelSize: 10 }
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
                            Text { anchors.centerIn: parent
                                text: modelData === null ? "" : modelData
                                color: parent.isToday ? root.bg
                                     : index % 7 >= 5 ? root.dim : root.fg
                                font.family: root.fontName; font.pixelSize: 11 }
                        }
                    }
                }
                Text { Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11 }
            }
        }
    }

    // ══ WIFI — over the wifi icon ══════════════════════════
    PanelWindow {
        id: wifiWin
        visible: root.openPanel === "wifi"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) pwField.forceActiveFocus()

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: wifiWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 320; height: 420
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: wifiWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelHeader { title: "WIFI" }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.wifiEnabled
                            ? (root.wifiSignal >= 0 ? "connected · " + root.wifiSignal + "%" : "not connected")
                            : "wifi off"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12
                        elide: Text.ElideRight; Layout.fillWidth: true }
                    Rectangle {
                        width: 50; height: 22; radius: 4
                        color: root.wifiEnabled ? root.accent : root.bgLight
                        Text { anchors.centerIn: parent; text: root.wifiEnabled ? "on" : "off"
                            color: root.wifiEnabled ? root.bg : root.dim
                            font.family: root.fontName; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { nmAction.cmd = root.wifiEnabled ? "radio wifi off" : "radio wifi on"; nmAction.running = true; } }
                    }
                }
                ColumnLayout {
                    visible: root.pendingSsid !== ""
                    Layout.fillWidth: true; spacing: 4
                    Text { text: "password for \"" + root.pendingSsid + "\""; color: root.dim
                        font.family: root.fontName; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 4
                        TextField {
                            id: pwField
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            font.family: root.fontName; font.pixelSize: 11; color: root.fg
                            background: Rectangle { radius: 4; color: root.bgLight; border.color: root.borderCol }
                            Keys.onReturnPressed: root.connectWifi(root.pendingSsid, pwField.text)
                            Keys.onEnterPressed:  root.connectWifi(root.pendingSsid, pwField.text)
                            Keys.onEscapePressed: root.closePanel()
                        }
                        Rectangle {
                            width: 60; height: 24; radius: 4; color: root.accent
                            Text { anchors.centerIn: parent; text: "go"; color: root.bg
                                font.family: root.fontName; font.pixelSize: 10 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWifi(root.pendingSsid, pwField.text) }
                        }
                    }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 2
                    model: root.networks
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 26
                        radius: 4
                        color: wma.containsMouse ? root.bgLight : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: modelData.signal + "%"; color: root.dim
                                font.family: root.fontName; font.pixelSize: 10; Layout.preferredWidth: 32 }
                            Text { text: modelData.ssid; color: root.fg; font.family: root.fontName
                                font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: (modelData.sec !== "" && modelData.sec !== "--") ? root.iLock : ""
                                font.family: root.fontName; color: root.dim; font.pixelSize: 10 }
                            Text { text: modelData.active ? root.iCheck : ""; font.family: root.fontName
                                color: root.accent; font.pixelSize: 10 }
                        }
                        MouseArea {
                            id: wma
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

    // ══ BLUETOOTH — centered ═══════════════════════════════════════
    PanelWindow {
        id: btWin
        visible: root.openPanel === "bt"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: btWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 310; height: 350
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: btWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelHeader { title: "BLUETOOTH" }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.btPowered ? "Bluetooth on" : "Bluetooth off"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 12; Layout.fillWidth: true }
                    Rectangle {
                        width: 56; height: 24; radius: root.round
                        color: root.btPowered ? root.accent : root.bgLight
                        Text { anchors.centerIn: parent; text: root.btPowered ? "on" : "off"
                            color: root.btPowered ? root.bg : root.dim
                            font.family: root.fontName; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { btAction.cmd = root.btPowered ? "power off" : "power on"; btAction.running = true; } }
                    }
                }
                Text { visible: root.btDevices.length === 0; text: "no paired devices"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11 }
                Repeater {
                    model: root.btDevices
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; height: 28; radius: root.round
                        color: ma.containsMouse ? root.bgLight : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Rectangle { width: 7; height: 7; radius: 3.5
                                color: modelData.connected ? root.green : root.dim }
                            Text { text: modelData.name; color: root.fg; font.family: root.fontName
                                font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: modelData.connected ? "disconnect" : "connect"
                                color: root.dim; font.family: root.fontName; font.pixelSize: 11 }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                btAction.cmd = (modelData.connected ? "disconnect " : "connect ") + modelData.mac;
                                btAction.running = true;
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { text: "pair new devices with bluetoothctl once —\nthey appear here after"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
            }
        }
    }

    // ══ BRIGHTNESS — centered ═════════════════════════════════════
    PanelWindow {
        id: briWin
        visible: root.openPanel === "bri"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: briWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 280; height: 120
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: briWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                PanelHeader { title: "BRIGHTNESS" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: root.iSun; font.family: root.fontName; font.pixelSize: 14; color: root.accent }
                    Slider {
                        id: briSlider
                        Layout.fillWidth: true
                        from: 1; to: 100; stepSize: 1
                        enabled: root.briAvail
                        Component.onCompleted: value = root.brightness
                        background: Rectangle {
                            y: (parent.height - height) / 2
                            width: parent.width; height: 4; radius: 2; color: root.bgLight
                            Rectangle { width: briSlider.visualPosition * parent.width; height: parent.height
                                radius: 2; color: root.accent }
                        }
                        handle: Rectangle {
                            x: briSlider.visualPosition * (briSlider.availableWidth - width)
                            y: (briSlider.availableHeight - height) / 2
                            width: 12; height: 12; radius: 6; color: root.fg
                        }
                        onMoved: {
                            briPending = Math.round(value);
                            briDebounce.restart();
                        }
                    }
                    Text { text: root.briAvail ? root.brightness + "%" : "—"
                        color: root.fg; font.family: root.fontName
                        font.pixelSize: 11; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                }
            }
        }
    }

    // ══ BATTERY — centered ══════════════════════════════════
    PanelWindow {
        id: batWin
        visible: root.openPanel === "bat"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: batWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 280; height: 150
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: batWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                PanelHeader { title: "BATTERY" }
                Text {
                    visible: !root.batPresent
                    text: "no battery detected (desktop system?)"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11
                }
                Rectangle {
                    visible: root.batPresent
                    Layout.fillWidth: true; height: 20; radius: root.round; color: root.bgLight
                    Rectangle {
                        width: parent.width * root.batCap / 100
                        height: parent.height; radius: root.round
                        color: root.batAlert ? root.red
                             : (root.batCharging || root.batIsFull) ? root.green : root.accent
                        opacity: 0.9
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.batCap + "%"
                        color: root.fg; font.family: root.fontName; font.pixelSize: 11
                    }
                }
                Text {
                    visible: root.batPresent
                    text: root.batStatus.toLowerCase()
                          + (root.batEstimate() !== "" ? " · " + root.batEstimate() : "")
                          + (root.batAlert ? "  — low battery" : "")
                    color: root.batAlert ? root.red : root.dim
                    font.family: root.fontName; font.pixelSize: 11
                }
            }
        }
    }

    // ══ NOTIFICATIONS — near center ════════════════════════
    PanelWindow {
        id: notifWin
        visible: root.openPanel === "notif"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: notifWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 320; height: 400
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: notifWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelHeader { title: "NOTIFICATIONS" }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.iMoon; font.family: root.fontName; font.pixelSize: 13
                        color: root.dnd ? root.accent : root.dim }
                    Text { text: "do not disturb"; color: root.fg; font.family: root.fontName
                        font.pixelSize: 12; Layout.fillWidth: true }
                    Rectangle {
                        width: 56; height: 24; radius: root.round
                        color: root.dnd ? root.accent : root.bgLight
                        Text { anchors.centerIn: parent; text: root.dnd ? "on" : "off"
                            color: root.dnd ? root.bg : root.dim
                            font.family: root.fontName; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.dnd = !root.dnd }
                    }
                }
                Text { visible: root.notifs.length === 0; text: "no notifications"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 11 }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: root.notifs
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: ncol.implicitHeight + 12
                        radius: root.round
                        color: root.bgLight
                        ColumnLayout {
                            id: ncol
                            anchors.fill: parent; anchors.margins: 6
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: modelData.title; color: root.fg; font.family: root.fontName
                                    font.pixelSize: 12; font.bold: true; elide: Text.ElideRight
                                    Layout.fillWidth: true }
                                Text { text: "×"; color: root.dim; font.pixelSize: 13
                                    MouseArea { anchors.fill: parent; anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.dismiss(modelData) } }
                            }
                            Text { visible: modelData.body !== ""; text: modelData.body; color: root.dim
                                font.family: root.fontName; font.pixelSize: 11
                                wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Text { text: modelData.app; color: root.dim; font.family: root.fontName
                                font.pixelSize: 10; opacity: 0.7 }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: root.round; color: root.bgLight
                    Text { anchors.centerIn: parent; text: "clear all"; color: root.fg
                        font.family: root.fontName; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearNotifs() }
                }
            }
        }
    }

    // ══ REMINDERS — near center ════════════════════════════
    PanelWindow {
        id: remWin
        visible: root.openPanel === "rem"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onVisibleChanged: if (visible) remText.forceActiveFocus()

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 42
            color: "#77000000"
            opacity: remWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
        }

        Rectangle {
            width: 320; height: 260
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: remWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Text { text: "REMINDERS"; color: root.dim
                    font { family: root.fontName; pixelSize: 10; letterSpacing: 2 } }

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    TextField {
                        id: remText
                        Layout.fillWidth: true
                        font.family: root.fontName; font.pixelSize: 11; color: root.fg
                        placeholderText: "remind me to…"; placeholderTextColor: root.dim
                        leftPadding: 8; topPadding: 6; bottomPadding: 6
                        background: Rectangle { radius: 4; color: root.bgLight; border.color: root.borderCol }
                        Keys.onReturnPressed: root.addReminder(remText.text, remWhen.text)
                        Keys.onEnterPressed:  root.addReminder(remText.text, remWhen.text)
                    }
                    TextField {
                        id: remWhen
                        Layout.preferredWidth: 64
                        font.family: root.fontName; font.pixelSize: 11; color: root.fg
                        placeholderText: "when"; placeholderTextColor: root.dim
                        leftPadding: 8; topPadding: 6; bottomPadding: 6
                        background: Rectangle { radius: 4; color: root.bgLight; border.color: root.borderCol }
                        Keys.onReturnPressed: root.addReminder(remText.text, remWhen.text)
                        Keys.onEnterPressed:  root.addReminder(remText.text, remWhen.text)
                    }
                    Rectangle {
                        width: 40; height: 24; radius: 4; color: root.accent
                        Text { anchors.centerIn: parent; text: "add"; color: root.bg
                            font.family: root.fontName; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.addReminder(remText.text, remWhen.text) }
                    }
                }

                Text {
                    visible: root.remHint !== ""
                    text: root.remHint; color: root.red
                    font.family: root.fontName; font.pixelSize: 9
                }

                Text { visible: root.reminders.length === 0; text: "no reminders"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 10 }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 2
                    model: root.reminders
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: 24
                        radius: 4
                        color: rmMa.containsMouse ? root.bgLight : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: root.fmtLeftAt(modelData.when, root.nowTick)
                                color: root.accent; font.family: root.fontName; font.pixelSize: 10
                                Layout.preferredWidth: 56 }
                            Text { text: modelData.text; color: root.fg; font.family: root.fontName
                                font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: "×"; color: root.dim; font.pixelSize: 11
                                MouseArea { anchors.fill: parent; anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.delReminder(modelData) } }
                        }
                        MouseArea { id: rmMa; anchors.fill: parent; hoverEnabled: true }
                    }
                }

                Text { text: "15m · 1h · 14:30 — fires notification"
                    color: root.dim; font.family: root.fontName; font.pixelSize: 9 }
            }
        }
    }

    // ══ APP LAUNCHER — centered ═══════════════════════════════
    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        readonly property var results: {
            const q = search.text.toLowerCase();
            const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
            const list = q ? all.filter(e =>
                (e.name || "").toLowerCase().includes(q) ||
                (e.genericName || "").toLowerCase().includes(q)) : all;
            return list.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        }
        function launch(e) { if (!e) return; e.execute(); root.launcherOpen = false; }
        onVisibleChanged: if (visible) { search.text = ""; card2.sel = 0; search.forceActiveFocus(); }

        Rectangle {
            anchors.fill: parent
            color: "#88000000"
            opacity: launcher.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.launcherOpen = false }
        }

        Rectangle {
            id: card2
            property int sel: 0
            width: 420; height: 400
            anchors.centerIn: parent
            radius: root.round
            color: root.bg
            border.color: root.borderCol
            border.width: 1
            opacity: launcher.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: search
                    Layout.fillWidth: true
                    font.family: root.fontName; font.pixelSize: 13; color: root.fg
                    placeholderText: "search…"; placeholderTextColor: root.dim
                    leftPadding: 12; topPadding: 10; bottomPadding: 10
                    background: Rectangle {
                        radius: root.round; color: root.bgLight
                        border.color: search.activeFocus ? root.accent : root.borderCol
                    }
                    onTextChanged: card2.sel = 0
                    Keys.onEscapePressed: root.launcherOpen = false
                    Keys.onDownPressed: card2.sel = Math.min(card2.sel + 1, launcher.results.length - 1)
                    Keys.onUpPressed:   card2.sel = Math.max(card2.sel - 1, 0)
                    Keys.onReturnPressed: launcher.launch(launcher.results[card2.sel])
                    Keys.onEnterPressed:  launcher.launch(launcher.results[card2.sel])
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: launcher.results
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: appList.width
                        height: 32
                        radius: root.round
                        color: index === card2.sel || ma.containsMouse ? root.bgLight : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            IconImage { source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                width: 20; height: 20 }
                            Text { text: modelData.name; color: root.fg; font.family: root.fontName
                                font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.launch(modelData)
                        }
                    }
                }
            }
        }
    }

    // ══ POWER MENU — centered ══════════════════════════════════
    PanelWindow {
        id: powerWin
        visible: root.powerOpen
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.powerOpen = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#88000000"
            opacity: powerWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            MouseArea { anchors.fill: parent; onClicked: root.powerOpen = false }
        }

        Rectangle {
            width: 260; height: 220
            anchors.centerIn: parent
            radius: root.round
            color: root.bg; border.color: root.borderCol; border.width: 1
            opacity: powerWin.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text { text: "POWER"; color: root.dim
                    font { family: root.fontName; pixelSize: 10; letterSpacing: 2 }
                    Layout.alignment: Qt.AlignHCenter }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: root.round
                        color: psleepMa.containsMouse ? root.bgLight : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: root.iSleep; font.family: root.fontName; font.pixelSize: 16
                                color: root.fg; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "sleep"; font.family: root.fontName; font.pixelSize: 9
                                color: root.dim; Layout.alignment: Qt.AlignHCenter }
                        }
                        MouseArea { id: psleepMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.powerOpen = false; Quickshell.exec(["systemctl", "suspend"]); } }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: root.round
                        color: plogMa.containsMouse ? root.bgLight : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: root.iLogout; font.family: root.fontName; font.pixelSize: 16
                                color: root.fg; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "logout"; font.family: root.fontName; font.pixelSize: 9
                                color: root.dim; Layout.alignment: Qt.AlignHCenter }
                        }
                        MouseArea { id: plogMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.powerOpen = false; Quickshell.exec(["loginctl", "terminate-user", Quickshell.env("USER")]); } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: root.round
                        color: phibMa.containsMouse ? root.bgLight : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: root.iHibernate; font.family: root.fontName; font.pixelSize: 16
                                color: root.fg; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "hibernate"; font.family: root.fontName; font.pixelSize: 9
                                color: root.dim; Layout.alignment: Qt.AlignHCenter }
                        }
                        MouseArea { id: phibMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.powerOpen = false; Quickshell.exec(["systemctl", "hibernate"]); } }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: root.round
                        color: prebootMa.containsMouse ? root.bgLight : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: root.iReboot; font.family: root.fontName; font.pixelSize: 16
                                color: root.fg; Layout.alignment: Qt.AlignHCenter }
                            Text { text: "reboot"; font.family: root.fontName; font.pixelSize: 9
                                color: root.dim; Layout.alignment: Qt.AlignHCenter }
                        }
                        MouseArea { id: prebootMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.powerOpen = false; Quickshell.exec(["systemctl", "reboot"]); } }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 50; radius: root.round
                    color: poffMa.containsMouse ? "#5c2030" : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout {
                        anchors.centerIn: parent; spacing: 8
                        Text { text: root.iPower; font.family: root.fontName; font.pixelSize: 16
                            color: root.red }
                        Text { text: "shutdown"; font.family: root.fontName; font.pixelSize: 11
                            color: root.red }
                    }
                    MouseArea { id: poffMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.powerOpen = false; Quickshell.exec(["systemctl", "poweroff"]); } }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
