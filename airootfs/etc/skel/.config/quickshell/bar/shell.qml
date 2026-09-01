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
    property string openPanel: ""        // "cal" | "wifi" | "bt" | "bri" | "notif"

    // ── rounding: exactly 5px everywhere ───────────────────
    readonly property int round: 5

    // ── Solitude palette ───────────────────────────────────
    readonly property color bg:        "#171922"
    readonly property color bgLight:   "#242838"
    readonly property color borderCol: "#2a2f42"
    readonly property color fg:        "#c4c9e4"
    readonly property color dim:       "#7a80a5"
    readonly property color accent:    "#a8b4f0"
    readonly property color green:     "#98c1a4"
    readonly property string fontName: "JetBrainsMono Nerd Font"

    // ── icons as ASCII escapes — copy-paste safe ───────────
    readonly property string iLaunch: "\uf135"
    readonly property string iWifi:   "\uf1eb"
    readonly property string iBt:     "\uf294"
    readonly property string iSun:    "\uf185"
    readonly property string iBell:   "\uf0f3"
    readonly property string iMoon:   "\uf186"
    readonly property string iLock:   "\uf023"
    readonly property string iCheck:  "\uf00c"

    // ── state ──────────────────────────────────────────────
    property bool btPowered: false
    property int  btConnected: 0
    property var  btDevices: []
    property bool wifiEnabled: false
    property int  wifiSignal: -1
    property var  networks: []
    property string pendingSsid: ""
    property int  brightness: 0
    property var  notifs: []             // {obj, title, body, app, expires}
    property bool dnd: false

    readonly property var panelTitles: ({ cal: "Calendar", wifi: "Wifi", bt: "Bluetooth",
                                          bri: "Brightness", notif: "Notifications" })
    readonly property var panelSizes:  ({ cal: [300, 340], wifi: [320, 430], bt: [300, 360],
                                          bri: [280, 150], notif: [340, 420] })

    function togglePanel(name) { openPanel = (openPanel === name ? "" : name); }
    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }
    function connectWifi(ssid, pass) {
        nmAction.cmd = "nmcli device wifi connect " + shq(ssid) +
                       (pass ? " password " + shq(pass) : "");
        nmAction.running = true;
        pendingSsid = "";
    }
    function dismiss(n) { n.obj.close(); root.notifs = root.notifs.filter(x => x !== n); }
    function clearNotifs() {
        for (const n of root.notifs) n.obj.close();
        root.notifs = [];
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

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
                        map[ssid] = { ssid, signal: sig, sec: p[3] || "", active: p[0] === "yes" };
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

    // ══ BRIGHTNESS ═════════════════════════════════════════
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -m"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const f of text.trim().split(","))
                    if (f.endsWith("%")) root.brightness = parseInt(f) || 0;
            }
        }
    }

    Process {
        id: briSet
        property string cmd: ""
        command: ["sh", "-c", "brightnessctl " + cmd]
        stdout: StdioCollector { onStreamFinished: briProc.running = true }
    }

    // ══ poll timers ════════════════════════════════════════
    Timer { interval: 5000; triggeredOnStart: true; repeat: true; running: true
            onTriggered: { btStatus.running = true; wifiStatus.running = true; briProc.running = true } }
    Timer { interval: 4000; triggeredOnStart: true; repeat: true; running: root.openPanel === "bt"
            onTriggered: btDevicesProc.running = true }
    Timer { interval: 6000; triggeredOnStart: true; repeat: true; running: root.openPanel === "wifi"
            onTriggered: wifiScan.running = true }

    // ══ building blocks ════════════════════════════════════
    component IconBtn: Rectangle {
        id: btn
        property string icon
        property bool dimmed: false
        property bool accented: false
        signal activated()
        signal wheeled(int delta)
        width: 28; height: 20; radius: root.round
        color: ma.containsMouse ? root.bgLight : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: root.fontName
            font.pixelSize: 11
            color: btn.dimmed ? root.dim : (btn.accented ? root.accent : root.fg)
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
            onWheel: w => btn.wheeled(w.angleDelta.y)
        }
    }

    // ── panel contents (loaded into the overlay card) ──────

    component CalContent: ColumnLayout {
        anchors.fill: parent
        spacing: 6
        property date viewDate: clock.date
        function addMonths(d, n) { const x = new Date(d); x.setMonth(x.getMonth() + n); return x; }
        readonly property var cells: {
            const y = viewDate.getFullYear(), m = viewDate.getMonth();
            const offset = (new Date(y, m, 1).getDay() + 6) % 7;
            const days = new Date(y, m + 1, 0).getDate();
            const out = [];
            for (let i = 0; i < offset; i++) out.push(null);
            for (let d = 1; d <= days; d++) out.push(d);
            return out;
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "‹"; color: root.dim; font.family: root.fontName; font.pixelSize: 14
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                    onClicked: cal.viewDate = cal.addMonths(cal.viewDate, -1) } }
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDateTime(cal.viewDate, "MMMM yyyy")
                color: root.fg; font.family: root.fontName; font.pixelSize: 12 }
            Text { text: "›"; color: root.dim; font.family: root.fontName; font.pixelSize: 14
                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                    onClicked: cal.viewDate = cal.addMonths(cal.viewDate, 1) } }
        }
        Row {
            Layout.alignment: Qt.AlignHCenter; spacing: 2
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Text { required property string modelData
                    width: 34; horizontalAlignment: Text.AlignHCenter
                    text: modelData; color: root.dim; font.family: root.fontName; font.pixelSize: 9 }
            }
        }
        Grid {
            id: cal
            Layout.alignment: Qt.AlignHCenter; columns: 7; spacing: 2
            Repeater {
                model: cal.cells
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    readonly property bool isToday:
                        modelData !== null &&
                        cal.viewDate.getFullYear() === clock.date.getFullYear() &&
                        cal.viewDate.getMonth() === clock.date.getMonth() &&
                        modelData === clock.date.getDate()
                    width: 34; height: 26; radius: root.round
                    color: isToday ? root.accent : "transparent"
                    Text { anchors.centerIn: parent
                        text: modelData === null ? "" : modelData
                        color: parent.isToday ? root.bg : index % 7 >= 5 ? root.dim : root.fg
                        font.family: root.fontName; font.pixelSize: 10 }
                }
            }
        }
        Text { Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
    }

    component WifiContent: ColumnLayout {
        anchors.fill: parent
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.wifiEnabled
                    ? (root.wifiSignal >= 0 ? "connected · " + root.wifiSignal + "%" : "not connected")
                    : "wifi off"
                color: root.fg; font.family: root.fontName; font.pixelSize: 11
                elide: Text.ElideRight; Layout.fillWidth: true }
            Rectangle {
                width: 56; height: 22; radius: root.round
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
            Layout.fillWidth: true; spacing: 6
            Text { text: "password for \"" + root.pendingSsid + "\""; color: root.dim
                font.family: root.fontName; font.pixelSize: 10 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField {
                    id: pwField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    font.family: root.fontName; font.pixelSize: 11; color: root.fg
                    background: Rectangle { radius: root.round; color: root.bgLight; border.color: root.borderCol }
                    Keys.onReturnPressed: root.connectWifi(root.pendingSsid, pwField.text)
                    Keys.onEnterPressed:  root.connectWifi(root.pendingSsid, pwField.text)
                }
                Rectangle {
                    width: 64; height: 26; radius: root.round; color: root.accent
                    Text { anchors.centerIn: parent; text: "connect"; color: root.bg
                        font.family: root.fontName; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.connectWifi(root.pendingSsid, pwField.text) }
                }
            }
        }
        Text { text: "networks"; color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
        Repeater {
            model: root.networks
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; height: 26; radius: root.round
                color: ma.containsMouse ? root.bgLight : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Text { text: modelData.signal + "%"; color: root.dim
                        font.family: root.fontName; font.pixelSize: 9; Layout.preferredWidth: 30 }
                    Text { text: modelData.ssid; color: root.fg; font.family: root.fontName
                        font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: (modelData.sec !== "" && modelData.sec !== "--") ? root.iLock : ""
                        font.family: root.fontName; color: root.dim; font.pixelSize: 10 }
                    Text { text: modelData.active ? root.iCheck : ""; font.family: root.fontName
                        color: root.accent; font.pixelSize: 10 }
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

    component BtContent: ColumnLayout {
        anchors.fill: parent
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.btPowered ? "Bluetooth on" : "Bluetooth off"
                color: root.fg; font.family: root.fontName; font.pixelSize: 11; Layout.fillWidth: true }
            Rectangle {
                width: 56; height: 22; radius: root.round
                color: root.btPowered ? root.accent : root.bgLight
                Text { anchors.centerIn: parent; text: root.btPowered ? "on" : "off"
                    color: root.btPowered ? root.bg : root.dim
                    font.family: root.fontName; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { btAction.cmd = root.btPowered ? "power off" : "power on"; btAction.running = true; } }
            }
        }
        Text { visible: root.btDevices.length === 0; text: "no paired devices"
            color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
        Repeater {
            model: root.btDevices
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; height: 28; radius: root.round
                color: ma.containsMouse ? root.bgLight : "transparent"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    Rectangle { width: 6; height: 6; radius: 3
                        color: modelData.connected ? root.green : root.dim }
                    Text { text: modelData.name; color: root.fg; font.family: root.fontName
                        font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: modelData.connected ? "disconnect" : "connect"
                        color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
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
            color: root.dim; font.family: root.fontName; font.pixelSize: 9 }
    }

    component BriContent: ColumnLayout {
        anchors.fill: parent
        spacing: 8
        Connections {
            target: root
            function onBrightnessChanged() { if (!briSlider.pressed) briSlider.value = root.brightness }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: root.iSun; font.family: root.fontName; font.pixelSize: 14; color: root.accent }
            Slider {
                id: briSlider
                Layout.fillWidth: true
                from: 1; to: 100
                Component.onCompleted: value = root.brightness
                background: Rectangle {
                    y: (parent.height - height) / 2
                    width: parent.width; height: 5; radius: 2; color: root.bgLight
                    Rectangle { width: briSlider.visualPosition * parent.width; height: parent.height
                        radius: 2; color: root.accent }
                }
                handle: Rectangle {
                    x: briSlider.visualPosition * (briSlider.availableWidth - width)
                    y: (briSlider.availableHeight - height) / 2
                    width: 12; height: 12; radius: 6; color: root.fg
                }
                onMoved: { briSet.cmd = "set " + Math.round(value) + "%"; briSet.running = true; }
            }
            Text { text: root.brightness + "%"; color: root.fg; font.family: root.fontName
                font.pixelSize: 11; Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight }
        }
        Text { text: "scroll the sun icon in the bar for quick ±5%"
            color: root.dim; font.family: root.fontName; font.pixelSize: 9 }
    }

    component NotifContent: ColumnLayout {
        anchors.fill: parent
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.iMoon; font.family: root.fontName; font.pixelSize: 12
                color: root.dnd ? root.accent : root.dim }
            Text { text: "do not disturb"; color: root.fg; font.family: root.fontName
                font.pixelSize: 11; Layout.fillWidth: true }
            Rectangle {
                width: 56; height: 22; radius: root.round
                color: root.dnd ? root.accent : root.bgLight
                Text { anchors.centerIn: parent; text: root.dnd ? "on" : "off"
                    color: root.dnd ? root.bg : root.dim
                    font.family: root.fontName; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.dnd = !root.dnd }
            }
        }
        Text { visible: root.notifs.length === 0; text: "no notifications"
            color: root.dim; font.family: root.fontName; font.pixelSize: 10 }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 4
            model: root.notifs
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: ListView.view.width
                height: col.implicitHeight + 12
                radius: root.round
                color: ma.containsMouse ? root.bgLight : "#1f2230"
                ColumnLayout {
                    id: col
                    anchors.fill: parent; anchors.margins: 6
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: modelData.title; color: root.fg; font.family: root.fontName
                            font.pixelSize: 11; font.bold: true; elide: Text.ElideRight
                            Layout.fillWidth: true }
                        Text { text: "×"; color: root.dim; font.pixelSize: 12
                            MouseArea { anchors.fill: parent; anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismiss(modelData) } }
                    }
                    Text { visible: modelData.body !== ""; text: modelData.body; color: root.dim
                        font.family: root.fontName; font.pixelSize: 10
                        wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Text { text: modelData.app; color: root.dim; font.family: root.fontName
                        font.pixelSize: 9; opacity: 0.7 }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 26; radius: root.round; color: root.bgLight
            Text { anchors.centerIn: parent; text: "clear all"; color: root.fg
                font.family: root.fontName; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.clearNotifs() }
        }
    }

    // ══ THE BAR ════════════════════════════════════════════
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        margins { top: 5; left: 8; right: 8 }
        implicitHeight: 30
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: root.round
            color: root.bg
            border.color: root.borderCol
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                IconBtn {
                    icon: root.iLaunch
                    onActivated: root.useWalker ? Hyprland.dispatch("exec walker")
                                                : root.launcherOpen = !root.launcherOpen
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 4
                    Text {
                        id: timeText
                        text: Qt.formatDateTime(clock.date, "h:mm ap")
                        color: tma.containsMouse ? root.accent : root.fg
                        font.family: root.fontName; font.pixelSize: 11
                        MouseArea {
                            id: tma
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("cal")
                        }
                    }
                    IconBtn {
                        icon: root.iBell
                        accented: root.notifs.length > 0
                        dimmed: root.dnd && root.notifs.length === 0
                        onActivated: root.togglePanel("notif")
                    }
                }

                Item { Layout.fillWidth: true }

                IconBtn {
                    id: wifiBtn
                    icon: root.iWifi
                    dimmed: !root.wifiEnabled
                    accented: root.wifiEnabled && root.wifiSignal >= 0
                    onActivated: root.togglePanel("wifi")
                }
                IconBtn {
                    id: btBtn
                    icon: root.iBt
                    dimmed: !root.btPowered
                    accented: root.btConnected > 0
                    onActivated: root.togglePanel("bt")
                }
                IconBtn {
                    id: briBtn
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

    // ══ DROPDOWN OVERLAY — one window, all panels ══════════
    PanelWindow {
        id: panelLayer
        visible: root.openPanel !== ""
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.openPanel === "wifi"
                                     ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property int pw: root.panelSizes[root.openPanel]
                                  ? root.panelSizes[root.openPanel][0] : 300
        readonly property int ph: root.panelSizes[root.openPanel]
                                  ? root.panelSizes[root.openPanel][1] : 300

        // dim backdrop — starts below the bar so bar clicks still work
        Rectangle {
            y: 40; height: parent.height - 40
            anchors.left: parent.left; anchors.right: parent.right
            color: "#77000000"
            MouseArea { anchors.fill: parent; onClicked: root.openPanel = "" }
        }

        Rectangle {
            id: card
            width: panelLayer.pw; height: panelLayer.ph
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.rightMargin: 10
            radius: root.round
            color: root.bg
            border.color: root.borderCol
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.panelTitles[root.openPanel] ?? ""; color: root.dim
                        font.family: root.fontName; font.pixelSize: 10
                        font.letterSpacing: 2; font.capitalization: Font.AllUppercase }
                    Item { Layout.fillWidth: true }
                    Text { text: "×"; color: root.dim; font.pixelSize: 13
                        MouseArea { anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPanel = "" } }
                }

                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    active: root.openPanel === "cal"
                    sourceComponent: CalContent
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    active: root.openPanel === "wifi"
                    sourceComponent: WifiContent
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    active: root.openPanel === "bt"
                    sourceComponent: BtContent
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    active: root.openPanel === "bri"
                    sourceComponent: BriContent
                }
                Loader {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    active: root.openPanel === "notif"
                    sourceComponent: NotifContent
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
            MouseArea { anchors.fill: parent; onClicked: root.launcherOpen = false }
        }

        Rectangle {
            id: card2
            property int sel: 0
            width: 480; height: 420
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 140
            radius: root.round
            color: root.bg
            border.color: root.borderCol

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: search
                    Layout.fillWidth: true
                    font.family: root.fontName; font.pixelSize: 12; color: root.fg
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
                        height: 34
                        radius: root.round
                        color: index === card2.sel || ma.containsMouse ? root.bgLight : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
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
}
