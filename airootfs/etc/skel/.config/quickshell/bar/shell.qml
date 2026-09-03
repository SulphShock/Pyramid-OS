//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets

ShellRoot {
    id: root

    property bool launcherOpen
    property bool powerOpen
    property string openPanel: ""
    property bool btPowered
    property bool btBusy
    property int btConnected
    property var btDevices: []
    property bool wifiEnabled
    property int wifiSignal: -1
    property var networks: []
    property string pendingSsid: ""
    property int brightness
    property bool briAvail
    property int briPending
    property var notifs: []
    property bool dnd
    property var reminders: []
    property string remHint: ""
    property var notifQueue: []
    property bool batPresent
    property int batCap
    property string batStatus: ""
    property string batFamily: ""
    property real batNow
    property real batFull
    property real batRate
    property bool batAlerted
    property int nowTick: Date.now()

    readonly property int rad: 2
    readonly property color bg: "#1A1A1A"
    readonly property color surface: "#232323"
    readonly property color raised: "#2A2A2A"
    readonly property color borderCol: "#3A3A3A"
    readonly property color line: "#2D2D2D"
    readonly property color fg: "#E5E5E5"
    readonly property color dim: "#7A7A7A"
    readonly property color faint: "#4A4A4A"
    readonly property color accent: "#F0F0F0"
    readonly property color hover: "#2E2E2E"
    readonly property color sel: "#3A3A3A"
    readonly property color press: "#444444"
    readonly property color focus: "#9A9A9A"
    readonly property color scrim: "#CC000000"
    readonly property string fontName: "JetBrainsMono Nerd Font"
    readonly property bool batCharging: batStatus.indexOf("Charg") === 0
    readonly property bool batIsFull: batStatus.indexOf("Full") === 0
    readonly property bool batAlert: batPresent && !batCharging && !batIsFull && batCap > 0 && batCap < 15

    function togglePanel(n) { openPanel = openPanel === n ? "" : n }
    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }
    function connectWifi(ssid, pass) {
        nmAction.cmd = "nmcli device wifi connect " + shq(ssid) + (pass ? " password " + shq(pass) : "")
        nmAction.running = true
        pendingSsid = ""
    }
    function dismiss(n) { n.obj.close(); notifs = notifs.filter(x => x !== n) }
    function clearNotifs() { for (const n of notifs) n.obj.close(); notifs = [] }
    function pushNotify(t, b) { notifQueue = notifQueue.concat([{ t: t, b: b }]); pumpNotify() }
    function pumpNotify() {
        if (notifQueue.length === 0 || notifyProc.running) return
        const n = notifQueue.shift()
        notifyProc.cmd = "notify-send -a Shell " + shq(n.t) + " " + shq(n.b)
        notifyProc.running = true
    }
    function readClip() { clipHelper.text = ""; clipHelper.paste(); clipBox.text = clipHelper.text }
    function parseWhen(s) {
        s = s.trim().toLowerCase()
        let m = s.match(/^(\d+)\s*m?(in|min)?$/)
        if (m) return Date.now() + parseInt(m[1]) * 60000
        m = s.match(/^(\d+)\s*(h|hr|hour|hours)$/)
        if (m) return Date.now() + parseInt(m[1]) * 3600000
        m = s.match(/^(\d+)\s*h\s*(\d+)\s*m?$/)
        if (m) return Date.now() + (parseInt(m[1]) * 3600 + parseInt(m[2]) * 60) * 1000
        m = s.match(/^(\d{1,2}):(\d{2})$/)
        if (m) {
            const t = new Date()
            t.setHours(parseInt(m[1]), parseInt(m[2]), 0, 0)
            if (t.getTime() <= Date.now()) t.setDate(t.getDate() + 1)
            return t.getTime()
        }
        return 0
    }
    function fmtLeftAt(when, now) {
        const s = Math.max(0, Math.round((when - now) / 1000))
        if (s < 60) return s + "s"
        const m = Math.floor(s / 60)
        if (m < 60) return m + "m"
        const h = Math.floor(m / 60)
        return h + "h" + (m % 60 ? (m % 60) + "m" : "")
    }
    function saveReminders() {
        remSaveProc.cmd = "mkdir -p \"$HOME/.local/share/quickshell\"; printf %s " +
            shq(JSON.stringify(reminders)) + " > \"$HOME/.local/share/quickshell/reminders.json\""
        remSaveProc.running = true
    }
    function addReminder(text, whenStr) {
        const t = text.trim(), when = parseWhen(whenStr)
        if (!t) { remHint = "type what to remind you about"; return }
        if (!when) { remHint = "when: 15m · 1h30 · 14:30"; return }
        reminders = reminders.concat([{ when: when, text: t }]).sort((a, b) => a.when - b.when)
        saveReminders()
        remHint = ""
        remText.text = ""
        remWhen.text = ""
    }
    function delReminder(r) { reminders = reminders.filter(x => x !== r); saveReminders() }
    function batEstimate() {
        if (!batPresent || batRate <= 0 || batNow <= 0) return ""
        const mins = (batCharging ? (batFull - batNow) / batRate : batNow / batRate) * 60 * (batFamily === "E" ? 1e6 : 1)
        if (!isFinite(mins) || mins <= 0 || mins > 6000) return ""
        const h = Math.floor(mins / 60), m = Math.round(mins % 60)
        const t = (h > 0 ? h + "h " : "") + m + "m"
        return "~" + t + (batCharging ? " to full" : " left")
    }
    function launchEntry(e) {
        if (!e) return
        launcherOpen = false
        try { e.execute() } catch (err) { pushNotify("Launch failed", e.name + ": " + err) }
    }

    component T: Text {
        color: root.fg; font.family: root.fontName; font.pixelSize: 11
        renderType: Text.NativeRendering
    }

    component Icon: Item {
        property string name: "dot"
        property int sz: 14
        property real weight: 1.4
        property color col: root.fg
        width: sz; height: sz
        onNameChanged: cv.requestPaint()
        onColChanged: cv.requestPaint()
        onSzChanged: cv.requestPaint()
        onWeightChanged: cv.requestPaint()
        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.lineWidth = parent.weight
                ctx.strokeStyle = parent.col
                ctx.fillStyle = parent.col
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                const s = parent.sz, x = 0, y = 0
                ctx.translate(x + s / 2, y + s / 2)
                ctx.scale(s / 16, s / 16)
                ctx.translate(-8, -8)
                const r = (cx, cy, w, h) => ({ x: cx - w / 2, y: cy - h / 2, w, h })
                switch (parent.name) {
                    case "tux": {
                        ctx.beginPath(); ctx.arc(8, 4.5, 3.4, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.moveTo(4.6, 4.5); ctx.quadraticCurveTo(4.6, 10, 6, 12)
                        ctx.lineTo(5, 14.5); ctx.lineTo(7, 13.5); ctx.lineTo(8, 14); ctx.lineTo(9, 13.5)
                        ctx.lineTo(11, 14.5); ctx.lineTo(10, 12); ctx.quadraticCurveTo(11.4, 10, 11.4, 4.5)
                        ctx.closePath(); ctx.fill()
                        ctx.fillStyle = root.bg
                        ctx.beginPath(); ctx.arc(6.9, 4.2, 0.5, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.arc(9.1, 4.2, 0.5, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.moveTo(7.2, 5.4); ctx.quadraticCurveTo(8, 6.1, 8.8, 5.4); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(7.2, 6.6); ctx.quadraticCurveTo(8, 7.2, 8.8, 6.6); ctx.stroke()
                        break
                    }
                    case "wifi": {
                        for (let i = 0; i < 3; i++) {
                            const rad = 3 + i * 2.4
                            ctx.beginPath(); ctx.arc(8, 13, rad, Math.PI * 1.25, Math.PI * 1.75); ctx.stroke()
                        }
                        ctx.beginPath(); ctx.arc(8, 13, 0.9, 0, Math.PI * 2); ctx.fill()
                        break
                    }
                    case "bt": {
                        ctx.beginPath()
                        ctx.moveTo(7, 2); ctx.lineTo(9, 4); ctx.lineTo(7, 6)
                        ctx.lineTo(11, 10); ctx.lineTo(7, 14)
                        ctx.lineTo(7, 2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(11, 6); ctx.lineTo(7, 10); ctx.lineTo(11, 14); ctx.stroke()
                        break
                    }
                    case "bell": {
                        ctx.beginPath()
                        ctx.moveTo(4, 11); ctx.lineTo(12, 11)
                        ctx.moveTo(4, 11); ctx.quadraticCurveTo(4, 5, 8, 4); ctx.quadraticCurveTo(12, 5, 12, 11)
                        ctx.stroke()
                        ctx.beginPath(); ctx.arc(8, 13, 1.2, 0, Math.PI * 2); ctx.fill()
                        break
                    }
                    case "bell-off": {
                        ctx.beginPath()
                        ctx.moveTo(4, 11); ctx.lineTo(12, 11)
                        ctx.moveTo(4, 11); ctx.quadraticCurveTo(4, 5, 8, 4); ctx.quadraticCurveTo(12, 5, 12, 11)
                        ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(14, 14); ctx.lineWidth = parent.weight * 1.1; ctx.stroke()
                        break
                    }
                    case "sun": {
                        ctx.beginPath(); ctx.arc(8, 8, 2.4, 0, Math.PI * 2); ctx.stroke()
                        for (let i = 0; i < 8; i++) {
                            const a = i * Math.PI / 4
                            const x1 = 8 + Math.cos(a) * 4.2, y1 = 8 + Math.sin(a) * 4.2
                            const x2 = 8 + Math.cos(a) * 6, y2 = 8 + Math.sin(a) * 6
                            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
                        }
                        break
                    }
                    case "clip": {
                        ctx.beginPath()
                        ctx.rect(4, 4, 8, 11); ctx.stroke()
                        ctx.beginPath()
                        ctx.rect(6, 2.5, 4, 3); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(6, 9); ctx.lineTo(10, 9); ctx.moveTo(6, 11.5); ctx.lineTo(10, 11.5); ctx.stroke()
                        break
                    }
                    case "bat": {
                        ctx.beginPath()
                        ctx.rect(2.5, 6, 10, 7); ctx.stroke()
                        ctx.beginPath(); ctx.rect(12.5, 8, 1.2, 3); ctx.fill()
                        break
                    }
                    case "bat-fill": {
                        const pct = parent.fillLevel !== undefined ? parent.fillLevel : 1
                        ctx.beginPath()
                        ctx.rect(2.5, 6, 10, 7); ctx.stroke()
                        ctx.beginPath(); ctx.rect(12.5, 8, 1.2, 3); ctx.fill()
                        const w = Math.max(0, Math.min(1, pct)) * 8.5
                        ctx.fillRect(3.25, 6.75, w, 5.5)
                        break
                    }
                    case "moon": {
                        ctx.beginPath()
                        ctx.arc(10, 8, 5, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(12, 6, 4, 0, Math.PI * 2); ctx.fillStyle = root.bg; ctx.fill()
                        break
                    }
                    case "lock": {
                        ctx.beginPath()
                        ctx.moveTo(4, 8); ctx.lineTo(4, 14); ctx.lineTo(12, 14); ctx.lineTo(12, 8); ctx.closePath(); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(6, 8); ctx.lineTo(6, 5.5); ctx.quadraticCurveTo(6, 3.5, 8, 3.5); ctx.quadraticCurveTo(10, 3.5, 10, 5.5); ctx.lineTo(10, 8)
                        ctx.stroke()
                        break
                    }
                    case "check": {
                        ctx.beginPath()
                        ctx.moveTo(3, 8); ctx.lineTo(7, 12); ctx.lineTo(13, 4); ctx.stroke()
                        break
                    }
                    case "x": {
                        ctx.beginPath()
                        ctx.moveTo(4, 4); ctx.lineTo(12, 12); ctx.moveTo(12, 4); ctx.lineTo(4, 12); ctx.stroke()
                        break
                    }
                    case "arrow-l": {
                        ctx.beginPath()
                        ctx.moveTo(11, 4); ctx.lineTo(5, 8); ctx.lineTo(11, 12); ctx.stroke()
                        break
                    }
                    case "arrow-r": {
                        ctx.beginPath()
                        ctx.moveTo(5, 4); ctx.lineTo(11, 8); ctx.lineTo(5, 12); ctx.stroke()
                        break
                    }
                    case "power": {
                        ctx.beginPath()
                        ctx.moveTo(11, 4); ctx.quadraticCurveTo(14, 8, 11, 12); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(8, 3); ctx.lineTo(8, 9); ctx.stroke()
                        break
                    }
                    case "sleep": {
                        ctx.font = "10px " + root.fontName
                        ctx.textBaseline = "middle"
                        ctx.fillText("Z", 4, 5)
                        ctx.fillText("z", 7, 8.5)
                        ctx.fillText("z", 9.5, 12)
                        break
                    }
                    case "logout": {
                        ctx.beginPath()
                        ctx.rect(3, 3, 7, 10); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(8, 8); ctx.lineTo(13, 8); ctx.moveTo(11, 6); ctx.lineTo(13, 8); ctx.lineTo(11, 10); ctx.stroke()
                        break
                    }
                    case "reboot": {
                        ctx.beginPath()
                        ctx.arc(8, 8, 4.5, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(8, 2.5); ctx.lineTo(8, 5.5); ctx.lineTo(10.5, 3.5); ctx.closePath(); ctx.fill()
                        break
                    }
                    case "shutdown": {
                        ctx.beginPath()
                        ctx.arc(8, 8, 4, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath()
                        ctx.moveTo(8, 3); ctx.lineTo(8, 8); ctx.stroke()
                        break
                    }
                    case "calendar": {
                        ctx.beginPath()
                        ctx.rect(3, 4, 10, 10); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(3, 7); ctx.lineTo(13, 7); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(6, 2.5); ctx.lineTo(6, 5.5); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(10, 2.5); ctx.lineTo(10, 5.5); ctx.stroke()
                        break
                    }
                    case "remind": {
                        ctx.beginPath()
                        ctx.arc(8, 8, 5.5, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(8, 4.5); ctx.lineTo(8, 8); ctx.lineTo(10.5, 9.5); ctx.stroke()
                        break
                    }
                    case "dnd": {
                        ctx.beginPath()
                        ctx.moveTo(4, 11); ctx.lineTo(12, 11); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(4, 11); ctx.quadraticCurveTo(4, 5, 8, 4); ctx.quadraticCurveTo(12, 5, 12, 11)
                        ctx.stroke()
                        ctx.beginPath(); ctx.arc(8, 13, 1.2, 0, Math.PI * 2); ctx.fill()
                        ctx.beginPath(); ctx.moveTo(3, 3); ctx.lineTo(13, 13); ctx.stroke()
                        break
                    }
                    case "search": {
                        ctx.beginPath()
                        ctx.arc(7, 7, 3.5, 0, Math.PI * 2); ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(9.5, 9.5); ctx.lineTo(13, 13); ctx.stroke()
                        break
                    }
                    case "plus": {
                        ctx.beginPath()
                        ctx.moveTo(3, 8); ctx.lineTo(13, 8); ctx.moveTo(8, 3); ctx.lineTo(8, 13); ctx.stroke()
                        break
                    }
                    case "minus": {
                        ctx.beginPath()
                        ctx.moveTo(3, 8); ctx.lineTo(13, 8); ctx.stroke()
                        break
                    }
                    case "dot": {
                        ctx.beginPath(); ctx.arc(8, 8, 2, 0, Math.PI * 2); ctx.fill()
                        break
                    }
                    default: {
                        ctx.beginPath(); ctx.rect(4, 4, 8, 8); ctx.stroke()
                    }
                }
            }
        }
    }

    component Btn: Rectangle {
        id: btn
        property string label: ""
        property string icon: ""
        property int iconSize: 12
        property bool active: false
        property bool primary: false
        signal activated()
        implicitWidth: label !== "" ? Math.max(60, lt.implicitWidth + 18) : iconSize + 14
        implicitHeight: 22
        radius: root.rad
        color: active ? root.press : (ma.containsMouse ? root.hover : "transparent")
        border.width: 1
        border.color: primary ? root.fg : (active ? root.borderCol : (ma.containsMouse ? root.borderCol : "transparent"))
        Behavior on color { ColorAnimation { duration: 80 } }
        Row {
            anchors.centerIn: parent
            spacing: icon === "" || label === "" ? 0 : 6
            visible: icon !== "" || label !== ""
            Icon {
                visible: icon !== ""
                name: icon; sz: iconSize
                col: active ? root.bg : root.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            T {
                id: lt
                visible: label !== ""
                text: label
                color: active ? root.bg : root.fg
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    component Pill: Rectangle {
        property bool on
        signal flip()
        width: 36; height: 18; radius: root.rad
        color: on ? root.accent : root.surface
        border.width: 1
        border.color: on ? root.accent : root.borderCol
        Rectangle {
            x: parent.on ? parent.width - width - 2 : 2
            y: 2; width: parent.height - 6; height: parent.height - 6; radius: 1
            color: parent.on ? root.bg : root.dim
            Behavior on x { NumberAnimation { duration: 100 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.flip() }
    }

    component Field: TextField {
        color: root.fg; font.family: root.fontName; font.pixelSize: 11
        padding: 6; placeholderTextColor: root.faint
        selectByMouse: true
        background: Rectangle {
            radius: root.rad; color: root.surface
            border.width: 1
            border.color: parent.activeFocus ? root.focus : root.borderCol
        }
    }

    component Sep: Rectangle {
        property bool vert: false
        color: root.line
        implicitWidth: vert ? 1 : 1
        implicitHeight: vert ? 16 : 1
        Layout.fillWidth: !vert
        Layout.fillHeight: vert
    }

    component Overlay: PanelWindow {
        id: ov
        default property alias body: holder.data
        property bool shown
        property string label: ""
        property bool grab
        property int cw: 320
        property int ch: 380
        property real dim: 0.5
        property bool gap: true
        property color scrim: root.scrim
        signal opened()
        signal dismissed()
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: grab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        onShownChanged: if (shown) opened()
        Item { anchors.fill: parent; focus: true; Keys.onEscapePressed: ov.dismissed() }
        Rectangle {
            anchors.fill: parent; anchors.topMargin: ov.gap ? 40 : 0
            color: ov.scrim
            opacity: ov.shown ? (ov.dim > 0 ? 1 : 0.001) : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            MouseArea { anchors.fill: parent; onClicked: ov.dismissed() }
        }
        Rectangle {
            width: ov.cw; height: ov.ch; anchors.centerIn: parent
            radius: root.rad + 1
            color: root.bg
            border.width: 1
            border.color: root.borderCol
            opacity: ov.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 100 } }
            ColumnLayout {
                id: holder
                anchors.fill: parent; anchors.margins: 10; spacing: 8
                RowLayout {
                    Layout.fillWidth: true; visible: ov.label !== ""; spacing: 8
                    T {
                        text: ov.label
                        color: root.fg
                        font.family: root.fontName; font.pixelSize: 9; font.letterSpacing: 1.5
                        font.capitalization: Font.AllUppercase
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 16; height: 16; radius: 2; color: xma.containsMouse ? root.hover : "transparent"
                        Icon { name: "x"; sz: 10; col: root.dim; anchors.centerIn: parent }
                        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: ov.dismissed() }
                    }
                }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.launcherOpen = !root.launcherOpen }
    }
    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.powerOpen = !root.powerOpen }
    }

    NotificationServer {
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: notification => {
            if (root.dnd) { notification.close(); return }
            const ms = notification.expireTimeout
            root.notifs = root.notifs.concat([{
                obj: notification, title: notification.summary, body: notification.body,
                app: notification.appName, expires: ms > 0 ? Date.now() + ms : 0
            }])
        }
    }

    Timer {
        interval: 1000; repeat: true; running: root.notifs.length > 0
        onTriggered: {
            const now = Date.now()
            const keep = root.notifs.filter(n => n.expires === 0 || n.expires > now)
            if (keep.length !== root.notifs.length) root.notifs = keep
        }
    }

    Process {
        id: remLoadProc
        command: ["sh", "-c", "cat \"$HOME/.local/share/quickshell/reminders.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                try {
                    const arr = JSON.parse(text)
                    if (Array.isArray(arr))
                        root.reminders = arr.filter(r => r.when > Date.now()).sort((a, b) => a.when - b.when)
                } catch (e) { }
            }
        }
    }
    Process { id: remSaveProc; property string cmd: ""; command: ["sh", "-c", cmd] }
    Process {
        id: notifyProc
        property string cmd: ""
        command: ["sh", "-c", cmd]
        stdout: StdioCollector { onStreamFinished: root.pumpNotify() }
    }

    Component.onCompleted: { remLoadProc.running = true; batProc.running = true }

    Timer {
        interval: 5000; repeat: true; running: true
        onTriggered: {
            root.nowTick = Date.now()
            const due = root.reminders.filter(r => r.when <= Date.now())
            if (due.length) {
                for (const r of due) root.pushNotify("Reminder", r.text)
                root.reminders = root.reminders.filter(r => r.when > Date.now())
                root.saveReminders()
            }
            if (root.batAlert && !root.batAlerted) {
                root.batAlerted = true
                root.pushNotify("Battery", root.batCap + "% remaining")
            } else if (!root.batAlert) root.batAlerted = false
        }
    }

    Process {
        id: batProc
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "[ -z \"$b\" ] && { echo none; exit 0; }; " +
            "cat \"$b/capacity\" 2>/dev/null; cat \"$b/status\" 2>/dev/null; " +
            "if [ -r \"$b/energy_now\" ]; then echo \"E $(cat $b/energy_now 2>/dev/null) $(cat $b/energy_full 2>/dev/null) $(cat $b/power_now 2>/dev/null || echo 0)\"; " +
            "elif [ -r \"$b/charge_now\" ]; then echo \"C $(cat $b/charge_now 2>/dev/null) $(cat $b/charge_full 2>/dev/null) $(cat $b/current_now 2>/dev/null || echo 0)\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                if (!l[0] || l[0] === "none") { root.batPresent = false; return }
                root.batPresent = true
                root.batCap = parseInt(l[0]) || 0
                root.batStatus = (l[1] || "").trim()
                const m = (l[2] || "").split(/\s+/)
                if (m[0] === "E" || m[0] === "C") {
                    root.batFamily = m[0]
                    root.batNow = parseFloat(m[1]) || 0
                    root.batFull = parseFloat(m[2]) || 0
                    root.batRate = parseFloat(m[3]) || 0
                }
            }
        }
    }

    Process {
        id: btStatus
        command: ["sh", "-c",
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo p1 || echo p0; " +
            "bluetoothctl devices Connected 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                root.btPowered = l[0] === "p1"
                root.btConnected = parseInt(l[1]) || 0
            }
        }
    }
    Process {
        id: btScan
        command: ["bluetoothctl", "scan", "on"]
        running: root.openPanel === "bt" && root.btPowered
    }
    Process {
        id: btDevicesProc
        command: ["sh", "-c",
            "bluetoothctl devices 2>/dev/null | while read -r _ mac; do " +
            "info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "name=$(echo \"$info\" | sed -n 's/^[[:space:]]*Name: //p'); " +
            "conn=$(echo \"$info\" | sed -n 's/^[[:space:]]*Connected: //p'); " +
            "pair=$(echo \"$info\" | sed -n 's/^[[:space:]]*Paired: //p'); " +
            "echo \"$mac|$name|$conn|$pair\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const p = line.trim().split("|")
                    if (p.length === 4 && p[0])
                        list.push({ mac: p[0], name: p[1] || p[0], connected: p[2] === "yes", paired: p[3] === "yes" })
                }
                list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
                root.btDevices = list
            }
        }
    }
    Process {
        id: btAction
        property string cmd: ""
        command: ["sh", "-c", "bluetoothctl " + cmd]
        stdout: StdioCollector { onStreamFinished: {
            root.btBusy = false
            btStatus.running = true; btDevicesProc.running = true } }
    }

    Process {
        id: wifiStatus
        command: ["sh", "-c",
            "nmcli radio wifi; " +
            "nmcli -t -f ACTIVE,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1 ~ /yes/ {print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                root.wifiEnabled = (l[0] || "").indexOf("enabled") === 0
                const s = parseInt(l[1])
                root.wifiSignal = isNaN(s) ? -1 : s
            }
        }
    }
    Process {
        id: wifiScan
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                for (const line of text.split("\n")) {
                    const p = line.split(":")
                    if (p.length < 4) continue
                    const ssid = (p[1] || "").replace(/\\:/g, ":")
                    if (!ssid) continue
                    const sig = parseInt(p[2]) || 0
                    if (!map[ssid] || sig > map[ssid].signal)
                        map[ssid] = { ssid: ssid, signal: sig, sec: p[3] || "", active: p[0] === "yes" }
                }
                root.networks = Object.values(map).sort((a, b) => b.signal - a.signal)
            }
        }
    }
    Process {
        id: nmAction
        property string cmd: ""
        command: ["sh", "-c", cmd]
        stdout: StdioCollector { onStreamFinished: { wifiStatus.running = true; wifiScan.running = true } }
    }

    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || ""
                if (!line) { root.briAvail = false; return }
                const pct = line.split(",").find(f => f.trim().endsWith("%"))
                if (pct) root.brightness = parseInt(pct) || 0
                root.briAvail = !!pct
                if (!briSlider.pressed) briSlider.value = root.brightness
            }
        }
    }
    Process {
        id: briSet
        property string cmd: ""
        command: ["sh", "-c", "brightnessctl " + cmd]
        stdout: StdioCollector { onStreamFinished: briProc.running = true }
    }
    Timer {
        id: briDebounce; interval: 120
        onTriggered: {
            const v = Math.max(1, Math.min(100, root.briPending))
            briSet.cmd = "set " + v + "%"; briSet.running = true
        }
    }

    Timer {
        interval: 5000; triggeredOnStart: true; repeat: true; running: true
        onTriggered: { btStatus.running = true; wifiStatus.running = true; briProc.running = true; batProc.running = true }
    }
    Timer {
        interval: 4000; triggeredOnStart: true; repeat: true; running: root.openPanel === "bt"
        onTriggered: btDevicesProc.running = true
    }
    Timer {
        interval: 6000; triggeredOnStart: true; repeat: true; running: root.openPanel === "wifi"
        onTriggered: wifiScan.running = true
    }

    PanelWindow {
        anchors { top: true; left: true; right: true }
        margins { top: 4; left: 8; right: 8 }
        implicitHeight: 30
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: root.rad; color: root.bg
            border.width: 1; border.color: root.borderCol
            TextEdit { id: clipHelper; visible: false; width: 0; height: 0 }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 0
                    Rectangle {
                        width: 22; height: 22; radius: root.rad
                        color: lma.containsMouse ? root.hover : "transparent"
                        Icon { name: "tux"; sz: 16; anchors.centerIn: parent
                            col: lma.containsMouse ? root.accent : root.fg }
                        MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.launcherOpen = !root.launcherOpen }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: timeText.implicitWidth + 14
                        height: 22; radius: root.rad
                        color: tma.containsMouse ? root.hover : "transparent"
                        T {
                            id: timeText
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, "h:mm ap")
                            font.pixelSize: 12
                        }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("cal") }
                    }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 2
                        Rectangle {
                            visible: root.notifs.length > 0
                            width: nbadge.implicitWidth + 8; height: 16; radius: 2
                            color: root.surface
                            border.width: 1; border.color: root.borderCol
                            T { id: nbadge; anchors.centerIn: parent
                                text: root.notifs.length; font.pixelSize: 9; color: root.fg }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_nma.containsMouse ? root.hover : "transparent"
                            Icon {
                                anchors.centerIn: parent
                                name: root.dnd ? "dnd" : "bell"
                                sz: 13
                                col: root.dnd ? root.dim : root.fg
                            }
                            MouseArea { id: bar_nma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("notif") }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_wma.containsMouse ? root.hover : "transparent"
                            Icon {
                                anchors.centerIn: parent
                                name: "wifi"
                                sz: 13
                                col: root.wifiEnabled ? root.fg : root.dim
                                opacity: root.wifiEnabled ? (root.wifiSignal >= 50 ? 1 : (root.wifiSignal >= 0 ? 0.65 : 0.35)) : 0.3
                            }
                            MouseArea { id: bar_wma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("wifi") }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_bma.containsMouse ? root.hover : "transparent"
                            Icon {
                                anchors.centerIn: parent
                                name: "bt"; sz: 13
                                col: root.btConnected > 0 ? root.accent : (root.btPowered ? root.fg : root.dim)
                                opacity: root.btPowered ? 1 : 0.35
                            }
                            MouseArea { id: bar_bma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("bt") }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_sma.containsMouse ? root.hover : "transparent"
                            Icon { name: "sun"; sz: 13; col: root.fg; anchors.centerIn: parent }
                            MouseArea { id: bar_sma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("bri")
                                onWheel: w => {
                                    const v = Math.max(1, Math.min(100, root.brightness + (w.angleDelta.y > 0 ? 5 : -5)))
                                    briSet.cmd = "set " + v + "%"; briSet.running = true
                                } }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_cma.containsMouse ? root.hover : "transparent"
                            Icon { name: "clip"; sz: 13; col: root.fg; anchors.centerIn: parent }
                            MouseArea { id: bar_cma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("clip") }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_rma.containsMouse ? root.hover : "transparent"
                            Icon { name: "remind"; sz: 13; col: root.fg; anchors.centerIn: parent }
                            MouseArea { id: bar_rma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("rem") }
                        }
                        Rectangle {
                            width: batRow.implicitWidth + 10; height: 22; radius: root.rad
                            color: bar_bama.containsMouse ? root.hover : "transparent"
                            Row {
                                id: batRow; anchors.centerIn: parent; spacing: 4
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "bat"; sz: 12
                                    col: root.batAlert ? root.fg : (root.batPresent ? root.fg : root.dim)
                                }
                                T {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.batPresent ? root.batCap + "%" : "—"
                                    font.pixelSize: 10
                                    color: root.batAlert ? root.fg : (root.batPresent ? root.dim : root.dim)
                                }
                            }
                            MouseArea { id: bar_bama; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.togglePanel("bat") }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: root.rad
                            color: bar_pma.containsMouse ? root.hover : "transparent"
                            Icon { name: "power"; sz: 13; col: root.fg; anchors.centerIn: parent }
                            MouseArea { id: bar_pma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.powerOpen = !root.powerOpen }
                        }
                    }
            }
        }
    }

    Overlay {
        id: cal
        shown: root.openPanel === "cal"
        label: "Calendar"; cw: 300; ch: 320
        onDismissed: root.openPanel = ""
        onOpened: viewDate = clock.date
        property date viewDate: clock.date
        function shift(n) { const d = new Date(viewDate); d.setMonth(d.getMonth() + n); viewDate = d }
        readonly property var cells: {
            const y = viewDate.getFullYear(), m = viewDate.getMonth()
            const out = []
            for (let i = 0; i < (new Date(y, m, 1).getDay() + 6) % 7; i++) out.push(null)
            for (let d = 1; d <= new Date(y, m + 1, 0).getDate(); d++) out.push(d)
            return out
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 4
            Rectangle {
                width: 22; height: 22; radius: root.rad
                color: ama.containsMouse ? root.hover : "transparent"
                Icon { name: "arrow-l"; sz: 12; col: root.fg; anchors.centerIn: parent }
                MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(-1) }
            }
            T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDateTime(cal.viewDate, "MMMM yyyy"); font.pixelSize: 13 }
            Rectangle {
                width: 22; height: 22; radius: root.rad
                color: dma.containsMouse ? root.hover : "transparent"
                Icon { name: "arrow-r"; sz: 12; col: root.fg; anchors.centerIn: parent }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: cal.shift(1) }
            }
        }
        Row {
            Layout.alignment: Qt.AlignHCenter; spacing: 0
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                T { required property string modelData; width: 34
                    horizontalAlignment: Text.AlignHCenter; text: modelData
                    color: root.dim; font.pixelSize: 9 }
            }
        }
        Grid {
            Layout.alignment: Qt.AlignHCenter; columns: 7; spacing: 2
            Repeater {
                model: cal.cells
                Rectangle {
                    required property int index
                    required property var modelData
                    readonly property bool today: modelData !== null &&
                        cal.viewDate.getFullYear() === clock.date.getFullYear() &&
                        cal.viewDate.getMonth() === clock.date.getMonth() &&
                        modelData === clock.date.getDate()
                    width: 34; height: 26; radius: 2
                    color: today ? root.accent : "transparent"
                    border.width: today ? 1 : 0
                    border.color: root.fg
                    T {
                        anchors.centerIn: parent
                        text: parent.modelData === null ? "" : parent.modelData
                        color: parent.today ? root.bg : (parent.index % 7 >= 5 ? root.dim : root.fg)
                        font.pixelSize: 10
                    }
                }
            }
        }
        T { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy"); color: root.dim; font.pixelSize: 10 }
    }

    Overlay {
        shown: root.openPanel === "wifi"
        label: "Wifi"; grab: true; cw: 320; ch: 400
        onDismissed: { root.openPanel = ""; root.pendingSsid = "" }
        onOpened: if (pwField.visible) pwField.forceActiveFocus()
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            T { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12
                text: root.wifiEnabled
                    ? (root.wifiSignal >= 0 ? "connected · " + root.wifiSignal + "%" : "not connected")
                    : "wifi off" }
            Pill { on: root.wifiEnabled
                onFlip: {
                    nmAction.cmd = root.wifiEnabled ? "radio wifi off" : "radio wifi on"
                    nmAction.running = true
                } }
        }
        Rectangle {
            visible: root.pendingSsid !== ""
            Layout.fillWidth: true; implicitHeight: pwCol.implicitHeight + 12
            radius: root.rad; color: root.surface
            border.width: 1; border.color: root.borderCol
            ColumnLayout {
                id: pwCol
                anchors.fill: parent; anchors.margins: 6; spacing: 6
                T { text: "password for \"" + root.pendingSsid + "\""; color: root.dim; font.pixelSize: 10 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Field {
                        id: pwField; Layout.fillWidth: true; echoMode: TextInput.Password
                        onAccepted: root.connectWifi(root.pendingSsid, text)
                        Keys.onEscapePressed: { root.pendingSsid = ""; root.openPanel = "" }
                    }
                    Btn { label: "go"; primary: true
                        onActivated: root.connectWifi(root.pendingSsid, pwField.text) }
                }
            }
        }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: root.networks
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 26; radius: 2
                color: wma.containsMouse ? root.hover : (modelData.active ? root.sel : "transparent")
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    T { text: modelData.signal + "%"; color: root.dim; font.pixelSize: 9
                        Layout.preferredWidth: 28 }
                    T { text: modelData.ssid; elide: Text.ElideRight; Layout.fillWidth: true }
                    Icon { visible: modelData.sec !== "" && modelData.sec !== "--"
                        name: "lock"; sz: 10; col: root.dim }
                    Icon { visible: modelData.active; name: "check"; sz: 10; col: root.fg }
                }
                MouseArea {
                    id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.active) return
                        if (modelData.sec !== "" && modelData.sec !== "--") {
                            root.pendingSsid = modelData.ssid
                            pwField.text = ""
                        } else root.connectWifi(modelData.ssid, "")
                    }
                }
            }
        }
    }

    Overlay {
        shown: root.openPanel === "bt"
        label: "Bluetooth"; cw: 320; ch: 400
        onDismissed: root.openPanel = ""
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            T { text: root.btPowered ? "Bluetooth on" : "Bluetooth off"; font.pixelSize: 12; Layout.fillWidth: true }
            Pill { on: root.btPowered
                onFlip: {
                    root.btBusy = false
                    btAction.cmd = root.btPowered ? "power off" : "power on"
                    btAction.running = true
                } }
        }
        T {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            visible: root.btPowered
            text: root.btBusy ? "working — if pairing, confirm on your device"
                : (root.btDevices.length === 0 ? "scanning… put your device in pairing mode"
                : "tap a device to pair or connect")
            color: root.dim; font.pixelSize: 10
        }
        T { visible: !root.btPowered; Layout.fillWidth: true
            text: "turn bluetooth on to find nearby devices"; color: root.dim; font.pixelSize: 10 }
        ListView {
            id: btList
            visible: root.btPowered
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: root.btDevices
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: btList.width; height: 28; radius: 2
                color: btma.containsMouse ? root.hover : (modelData.connected ? root.sel : "transparent")
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                    Rectangle { width: 6; height: 6; radius: 1
                        color: modelData.connected ? root.accent : (modelData.paired ? root.fg : root.dim) }
                    T { text: modelData.name; elide: Text.ElideRight; Layout.fillWidth: true }
                    T { text: modelData.connected ? "tap to end"
                            : root.btBusy ? "…" : modelData.paired ? "connect" : "pair"
                        color: root.dim; font.pixelSize: 9 }
                }
                MouseArea {
                    id: btma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.btBusy) return
                        root.btBusy = true
                        if (modelData.connected) btAction.cmd = "disconnect " + modelData.mac
                        else if (modelData.paired) btAction.cmd = "connect " + modelData.mac
                        else btAction.cmd = "pair " + modelData.mac + "; bluetoothctl trust " +
                             modelData.mac + "; bluetoothctl connect " + modelData.mac
                        btAction.running = true
                    }
                }
            }
        }
        T { Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "pairing: switch on, hold the bluetooth button until it blinks, then tap above"
            color: root.dim; font.pixelSize: 9 }
    }

    Overlay {
        shown: root.openPanel === "bri"
        label: "Brightness"; cw: 280; ch: 100
        onDismissed: root.openPanel = ""
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Icon { name: "sun"; sz: 14; col: root.fg }
            Slider {
                id: briSlider
                Layout.fillWidth: true
                from: 1; to: 100; stepSize: 1
                enabled: root.briAvail
                Component.onCompleted: value = root.brightness
                background: Rectangle {
                    x: briSlider.leftPadding
                    y: (parent.height - height) / 2
                    width: parent.availableWidth; height: 3; radius: 1; color: root.surface
                    Rectangle {
                        x: 0; y: 0; height: parent.height; radius: 1
                        width: briSlider.visualPosition * parent.width
                        color: root.fg
                    }
                }
                handle: Rectangle {
                    x: briSlider.leftPadding + briSlider.visualPosition * (briSlider.availableWidth - width)
                    y: (parent.availableHeight - height) / 2
                    width: 10; height: 10; radius: 1
                    color: briSlider.pressed ? root.fg : (briSlider.hovered ? root.fg : root.dim)
                }
                onMoved: { root.briPending = Math.round(value); briDebounce.restart() }
            }
            T { text: root.briAvail ? root.brightness + "%" : "—"
                Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight; font.pixelSize: 10 }
        }
    }

    Overlay {
        shown: root.openPanel === "bat"
        label: "Battery"; cw: 280; ch: 130
        onDismissed: root.openPanel = ""
        T { visible: !root.batPresent; text: "no battery detected"; color: root.dim }
        RowLayout {
            visible: root.batPresent
            Layout.fillWidth: true; spacing: 10
            Icon { name: "bat"; sz: 22; col: root.fg }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Rectangle {
                    Layout.fillWidth: true; height: 10; radius: 1; color: root.surface
                    border.width: 1; border.color: root.borderCol
                    Rectangle {
                        width: parent.width * root.batCap / 100; height: parent.height
                        color: root.batAlert ? root.accent : (root.batCharging || root.batIsFull ? root.fg : root.fg)
                        opacity: root.batAlert ? 0.7 : 1
                    }
                }
                T { text: root.batCap + "%"; font.pixelSize: 11 }
            }
        }
        T {
            visible: root.batPresent; Layout.fillWidth: true
            text: root.batStatus.toLowerCase()
                + (root.batEstimate() !== "" ? " · " + root.batEstimate() : "")
                + (root.batAlert ? "  — low" : "")
            color: root.dim; font.pixelSize: 10
        }
    }

    Overlay {
        shown: root.openPanel === "notif"
        label: "Notifications"; cw: 320; ch: 400
        onDismissed: root.openPanel = ""
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Icon { name: "moon"; sz: 13; col: root.fg; opacity: root.dnd ? 1 : 0.4 }
            T { text: "do not disturb"; font.pixelSize: 11; Layout.fillWidth: true }
            Pill { on: root.dnd; onFlip: root.dnd = !root.dnd }
        }
        T { visible: root.notifs.length === 0; text: "no notifications"; color: root.dim }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 4
            model: root.notifs
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: ncol.implicitHeight + 12
                radius: root.rad; color: root.surface
                border.width: 1; border.color: root.line
                ColumnLayout {
                    id: ncol
                    anchors.fill: parent; anchors.margins: 8; spacing: 3
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        T { text: modelData.title; font.bold: true; elide: Text.ElideRight
                            Layout.fillWidth: true; font.pixelSize: 11 }
                        Rectangle {
                            width: 14; height: 14; radius: 2
                            color: nxma.containsMouse ? root.hover : "transparent"
                            Icon { name: "x"; sz: 9; col: root.dim; anchors.centerIn: parent }
                            MouseArea { id: nxma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss(modelData) }
                        }
                    }
                    T { visible: modelData.body !== ""; text: modelData.body; color: root.dim
                        wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: 10 }
                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData.obj.actions
                            Btn { label: modelData.text; iconSize: 9
                                onActivated: modelData.invoke() }
                        }
                    }
                    T { text: modelData.app; color: root.faint; font.pixelSize: 9 }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 24; radius: root.rad
            color: ncma.containsMouse ? root.hover : root.surface
            border.width: 1; border.color: root.borderCol
            T { anchors.centerIn: parent; text: "clear all"; font.pixelSize: 10 }
            MouseArea { id: ncma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor; onClicked: root.clearNotifs() }
        }
    }

    Overlay {
        shown: root.openPanel === "rem"
        label: "Reminders"; grab: true; cw: 320; ch: 260
        onDismissed: root.openPanel = ""
        onOpened: remText.forceActiveFocus()
        RowLayout {
            Layout.fillWidth: true; spacing: 4
            Field {
                id: remText; Layout.fillWidth: true
                placeholderText: "remind me to…"
                onAccepted: root.addReminder(remText.text, remWhen.text)
            }
            Field {
                id: remWhen; Layout.preferredWidth: 64
                placeholderText: "when"
                onAccepted: root.addReminder(remText.text, remWhen.text)
            }
            Btn { label: "add"; primary: true
                onActivated: root.addReminder(remText.text, remWhen.text) }
        }
        T { visible: root.remHint !== ""; text: root.remHint; color: root.dim; font.pixelSize: 9 }
        T { visible: root.reminders.length === 0; text: "no reminders"; color: root.dim; font.pixelSize: 10 }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: root.reminders
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 24; radius: 2
                color: rmMa.containsMouse ? root.hover : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    T { text: root.fmtLeftAt(modelData.when, root.nowTick); color: root.dim
                        font.pixelSize: 9; Layout.preferredWidth: 48 }
                    T { text: modelData.text; elide: Text.ElideRight; Layout.fillWidth: true }
                    Rectangle {
                        width: 16; height: 16; radius: 2
                        color: xm.containsMouse ? root.hover : "transparent"
                        Icon { name: "x"; sz: 9; col: root.dim; anchors.centerIn: parent }
                        MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.delReminder(modelData) }
                    }
                }
                MouseArea { id: rmMa; anchors.fill: parent; hoverEnabled: true }
            }
        }
        T { text: "15m · 1h30 · 14:30 — fires a notification"; color: root.dim; font.pixelSize: 9 }
    }

    Overlay {
        shown: root.openPanel === "clip"
        label: "Clipboard"; cw: 320; ch: 220
        onDismissed: root.openPanel = ""
        onOpened: root.readClip()
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: root.rad; color: root.surface
            border.width: 1; border.color: root.borderCol
            TextEdit {
                id: clipBox
                anchors.fill: parent; anchors.margins: 8
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                color: root.fg; font.family: root.fontName; font.pixelSize: 11
            }
            T {
                anchors.centerIn: parent; visible: clipBox.text === ""
                text: "clipboard is empty"; color: root.dim
                font.family: root.fontName; font.pixelSize: 11
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 4
            Btn { label: "copy"; icon: "clip"; iconSize: 11
                onActivated: { clipBox.selectAll(); clipBox.copy() } }
            Item { Layout.fillWidth: true }
            Btn { label: "refresh"; onActivated: root.readClip() }
        }
    }

    Overlay {
        id: launchWin
        shown: root.launcherOpen
        grab: true; gap: false; dim: 0; cw: 420; ch: 400
        onDismissed: root.launcherOpen = false
        onOpened: { search.text = ""; sel = 0; search.forceActiveFocus() }
        property int sel: 0
        function launch(e) { root.launchEntry(e) }
        readonly property var results: {
            const q = search.text.toLowerCase()
            const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            const list = q ? all.filter(e =>
                (e.name || "").toLowerCase().includes(q) ||
                (e.genericName || "").toLowerCase().includes(q)) : all
            return list.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
        }
        Rectangle {
            Layout.fillWidth: true; height: 32; radius: root.rad
            color: root.surface; border.width: 1; border.color: root.borderCol
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                Icon { name: "search"; sz: 12; col: root.dim }
                Field {
                    id: search; Layout.fillWidth: true
                    font.pixelSize: 12; padding: 0
                    background: null
                    placeholderText: "search applications…"
                    onTextChanged: launchWin.sel = 0
                    onAccepted: launchWin.launch(launchWin.results[launchWin.sel])
                    Keys.onDownPressed: launchWin.sel = Math.min(launchWin.sel + 1, launchWin.results.length - 1)
                    Keys.onUpPressed: launchWin.sel = Math.max(launchWin.sel - 1, 0)
                    Keys.onEscapePressed: root.launcherOpen = false
                }
            }
        }
        ListView {
            id: appList
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 2
            model: launchWin.results
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: appList.width; height: 30; radius: 2
                color: index === launchWin.sel ? root.sel : (appma.containsMouse ? root.hover : "transparent")
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                    IconImage {
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        asynchronous: true
                    }
                    T { text: modelData.name; elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: 11 }
                    T { text: modelData.genericName || ""; color: root.dim; font.pixelSize: 9
                        visible: text !== "" }
                }
                MouseArea {
                    id: appma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: launchWin.launch(modelData)
                }
            }
        }
    }

    Overlay {
        shown: root.powerOpen
        grab: true; gap: false; dim: 0.4; label: "Power"; cw: 280; ch: 200
        onDismissed: root.powerOpen = false
        GridLayout {
            Layout.fillWidth: true; columns: 2; rowSpacing: 4; columnSpacing: 4
            Repeater {
                model: [
                    { i: "sleep", l: "Sleep", cmd: ["systemctl", "suspend"] },
                    { i: "logout", l: "Log out", cmd: ["loginctl", "terminate-user", Quickshell.env("USER")] },
                    { i: "reboot", l: "Reboot", cmd: ["systemctl", "reboot"] },
                    { i: "shutdown", l: "Shut down", cmd: ["systemctl", "poweroff"] }
                ]
                Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    radius: root.rad
                    color: pwma.containsMouse ? root.hover : root.surface
                    border.width: 1; border.color: root.borderCol
                    Behavior on color { ColorAnimation { duration: 80 } }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 2
                        Icon { name: tile.modelData.i; sz: 14; col: root.fg }
                        T { text: tile.modelData.l; font.pixelSize: 10; color: root.fg }
                    }
                    MouseArea {
                        id: pwma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.powerOpen = false; Quickshell.exec(tile.modelData.cmd) }
                    }
                }
            }
        }
    }
}
