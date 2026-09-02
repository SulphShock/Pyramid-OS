import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Widgets
import "theme"

Scope {
    id: root

    // ── Clock ──────────────────────────────────────────────
    property string currentTime: ""
    property string currentDate: ""
    function updateClock() {
        const now = new Date()
        root.currentTime = Qt.formatTime(now, "h:mm AP")
        root.currentDate = Qt.formatDate(now, "ddd M/d")
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateClock()
    }

    // ── WiFi state (nmcli) ─────────────────────────────────
    property bool wifiOn: true
    function refreshWifi() {
        wifiProc.running = true
    }
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f WIFI g"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                root.wifiOn = (data.trim() === "enabled")
            }
        }
    }

    // ── Volume ────────────────────────────────────────────
    property int volumePct: 0
    property bool volumeMuted: false
    function refreshVolume() {
        volProc.running = true
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                const m = data.trim().match(/Volume:\s*([0-9.]+)/)
                if (m) root.volumePct = Math.round(parseFloat(m[1]) * 100)
                root.volumeMuted = data.includes("MUTED")
            }
        }
    }

    // ── Brightness ────────────────────────────────────────
    property int backlightMax: 21333
    property int backlightNow: 21333
    property int brightnessPct: 100
    FileView {
        id: backlightMaxView
        path: "/sys/class/backlight/intel_backlight/max_brightness"
        onTextChanged: {
            const v = parseInt(backlightMaxView.text())
            if (v > 0) root.backlightMax = v
            root.brightnessPct = Math.round(root.backlightNow / root.backlightMax * 100)
        }
    }
    FileView {
        id: backlightNowView
        path: "/sys/class/backlight/intel_backlight/brightness"
        onTextChanged: {
            root.backlightNow = parseInt(backlightNowView.text())
            root.brightnessPct = Math.round(root.backlightNow / root.backlightMax * 100)
        }
    }
    function setBrightness(pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)))
        const target = Math.round(root.backlightMax * pct / 100)
        setBrightProc.command = ["sh", "-c", "echo " + target + " > /sys/class/backlight/intel_backlight/brightness"]
        setBrightProc.running = true
        root.brightnessPct = pct
    }
    Process { id: setBrightProc; running: false }

    // ── Settings Process ──────────────────────────────────
    Process { id: settingsProc; command: ["hyprsettings"] }

    // ── Token Usage ──────────────────────────────────────
    property string tokenSummary: "..."
    property int tokenTotal: 0
    property int tokenSessions: 0
    property string tokenDetail: ""
    property bool tokenPopupVisible: false
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tokenProc.running = true
    }
    Process {
        id: tokenProc
        command: ["python3", "/home/prakhyat/.config/quickshell/bar/tokenusage.py"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    var j = JSON.parse(data.trim())
                    root.tokenSummary = j.summary || "..."
                    root.tokenTotal = j.total || 0
                    root.tokenSessions = j.sessions || 0
                    root.tokenDetail = data.trim()
                } catch(e) {}
            }
        }
    }

    // ── Bluetooth adapter ─────────────────────────────────
    property var adapter: Bluetooth.adapters.length > 0 ? Bluetooth.adapters[0] : null

    // ── App Launcher ──────────────────────────────────────
    property bool launcherVisible: false
    property string searchText: ""
    property var filteredApps: []
    property int selectedIdx: 0

    property var allApps: []

    function parseExec(execStr) {
        let cleaned = (execStr || "")
            .replace(/%[fFuUdDnNickvm]/gi, "")
            .replace(/@@[uUfF]?\s*(?:%[fFuU])?\s*@@/g, "")
            .replace("%%", "%")
            .trim()
        let args = []
        let cur = ""
        let inQ = false
        let inSq = false
        for (let i = 0; i < cleaned.length; i++) {
            const c = cleaned[i]
            if (c === '"' && !inSq) { inQ = !inQ; continue }
            if (c === "'" && !inQ) { inSq = !inSq; continue }
            if ((c === ' ' || c === '\t') && !inQ && !inSq) {
                if (cur.length) { args.push(cur); cur = "" }
                continue
            }
            cur += c
        }
        if (cur.length) args.push(cur)
        return args
    }

    function iconSource(name) {
        if (!name) return ""
        if (name.startsWith("/")) return "file://" + name
        return Quickshell.iconPath(name, true)
    }

    function launchApp(app) {
        if (!app) return
        let args = parseExec(app.exec)
        if (args.length > 0) {
            Quickshell.execDetached(args)
        }
        root.launcherVisible = false
        root.searchText = ""
    }

    // ── App launcher data (scanned from .desktop files) ────
    property bool appsLoaded: false
    Process {
        id: appScanProc
        command: ["python3", "/home/prakhyat/.config/quickshell/bar/listapps.py"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                for (const line of data.split("\n")) {
                    if (!line) continue
                    const parts = line.split("\t")
                    if (parts.length < 5) continue
                    root.allApps.push({
                        name: parts[0],
                        generic: parts[1],
                        icon: parts[2],
                        id: parts[3],
                        exec: parts[4]
                    })
                }
            }
        }
        onExited: {
            root.appsLoaded = true
            root.filterApps("")
            console.log("[launcher] loaded", root.allApps.length, "apps")
        }
    }

    function loadApps() {
        appScanProc.running = true
    }

    function filterApps(query) {
        let q = query.toLowerCase()
        let result = []
        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i]
            if (!q
                || app.name.toLowerCase().includes(q)
                || (app.generic && app.generic.toLowerCase().includes(q))
                || app.id.toLowerCase().includes(q)) {
                result.push(app)
            }
        }
        filteredApps = result
        selectedIdx = 0
    }

    Component.onCompleted: {
        refreshWifi()
        refreshVolume()
        loadApps()
    }

    // ── The Bar Window ────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            anchors.left: true
            anchors.right: true
            anchors.bottom: true
            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: Theme.bg

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ══ Start Button ══════════════════════════
                Rectangle {
                    Layout.preferredWidth: Theme.barHeight
                    Layout.fillHeight: true
                    color: startArea.pressed ? Theme.pressed
                         : startArea.containsMouse ? Theme.hover : "transparent"

                    Grid {
                        anchors.centerIn: parent
                        rows: 2; columns: 2; spacing: 3
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 9; height: 9
                                color: startArea.containsMouse ? Theme.accent : Theme.text
                                radius: 1
                            }
                        }
                    }
                    MouseArea {
                        id: startArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.launcherVisible = !root.launcherVisible
                            root.searchText = ""
                            if (root.launcherVisible) {
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: Theme.barHeight - 16; color: Theme.border; Layout.alignment: Qt.AlignVCenter }

                // ══ Spacer (fills center) ═════════════════
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                // ══ Right controls ═════════════════════════
                Row {
                    Layout.fillHeight: true
                    spacing: 2
                    Layout.rightMargin: 6

                    // ── WiFi ────────────────────────────
                    Rectangle {
                        width: 32; height: Theme.barHeight
                        color: wifiArea.pressed ? Theme.pressed : wifiArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: root.wifiOn ? "\uF05A9" : "\uF05AA"
                            color: root.wifiOn ? Theme.accent : Theme.muted
                            font.pixelSize: 13
                            font.family: "Symbols Nerd Font"
                        }
                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                toggleProc.wifi = !root.wifiOn
                                toggleProc.running = true
                            }
                        }
                    }
                    Process {
                        id: toggleProc
                        property bool wifi: true
                        command: ["sh", "-c", "nmcli radio wifi " + (wifi ? "on" : "off")]
                        running: false
                        onExited: { root.wifiOn = toggleProc.wifi; root.refreshWifi() }
                    }

                    // ── Settings (gear) ──────────────────
                    Rectangle {
                        width: 32; height: Theme.barHeight
                        color: settingsArea.pressed ? Theme.pressed : settingsArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: "\u2699"
                            color: Theme.text
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: settingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: settingsProc.running = true
                        }
                    }

                    // ── Bluetooth ────────────────────────
                    Rectangle {
                        width: 32; height: Theme.barHeight
                        color: btArea.pressed ? Theme.pressed : btArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: adapter && adapter.enabled ? "\uF00AF" : "\uF00B2"
                            color: adapter && adapter.enabled ? Theme.accent : Theme.muted
                            font.pixelSize: 13
                            font.family: "Symbols Nerd Font"
                        }
                        MouseArea {
                            id: btArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { if (adapter) adapter.enabled = !adapter.enabled }
                        }
                    }

                    // ── Volume ───────────────────────────
                    Rectangle {
                        width: 32; height: Theme.barHeight
                        color: volArea.pressed ? Theme.pressed : volArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: root.volumeMuted ? "\uF0581" : root.volumePct === 0 ? "\uF0581"
                                 : root.volumePct < 30 ? "\uF057F" : root.volumePct < 70 ? "\uF0580" : "\uF057E"
                            color: Theme.text
                            font.pixelSize: 13
                            font.family: "Symbols Nerd Font"
                        }
                        MouseArea {
                            id: volArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: volPopup.visible = !volPopup.visible
                            onWheel: (wheel) => {
                                const step = wheel.angleDelta.y > 0 ? 5 : -5
                                volAdjust.step = step
                                volAdjust.running = true
                            }
                        }
                    }
                    Process {
                        id: volAdjust
                        property int step: 5
                        command: ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + step + "%"]
                        running: false
                        onExited: root.refreshVolume()
                    }

                    // ── Brightness ───────────────────────
                    Rectangle {
                        width: 32; height: Theme.barHeight
                        color: brightArea.pressed ? Theme.pressed : brightArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: root.brightnessPct > 60 ? "\uF00E0" : root.brightnessPct > 20 ? "\uF00DF" : "\uF00DE"
                            color: Theme.text
                            font.pixelSize: 13
                            font.family: "Symbols Nerd Font"
                        }
                        MouseArea {
                            id: brightArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: brightPopup.visible = !brightPopup.visible
                            onWheel: (wheel) => {
                                const step = wheel.angleDelta.y > 0 ? 10 : -10
                                root.setBrightness(root.brightnessPct + step)
                            }
                        }
                    }

                    Rectangle { width: 1; height: Theme.barHeight - 16; color: Theme.border }

                    // ── Token Usage ─────────────────────────
                    Rectangle {
                        width: 90; height: Theme.barHeight
                        color: tokenArea.pressed ? Theme.pressed : tokenArea.containsMouse ? Theme.hover : "transparent"
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: root.tokenSummary
                            color: Theme.muted
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: tokenArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.tokenPopupVisible = !root.tokenPopupVisible
                        }
                    }

                    // ── Clock ───────────────────────────
                    Column {
                        width: 78
                        height: Theme.barHeight
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentTime
                            color: Theme.text
                            font.pixelSize: 12
                            font.bold: true
                            font.family: Theme.fontFamily
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentDate
                            color: Theme.muted
                            font.pixelSize: 10
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }

            // ══ Launcher Popup (centered widget) ═════════════
            PopupWindow {
                id: launcherPopup
                visible: root.launcherVisible
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: (bar.screen.width - launcherPopup.implicitWidth) / 2
                anchor.rect.y: (bar.screen.height - bar.height - launcherPopup.implicitHeight) / 2 - bar.height
                implicitWidth: 420
                implicitHeight: 460
                color: "transparent"
                onVisibleChanged: {
                    if (!visible) {
                        root.launcherVisible = false
                        root.searchText = ""
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Search box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: Theme.surface2
                            radius: 6
                            border.color: searchInput.activeFocus ? Theme.accent : Theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: "\uF002"
                                    color: Theme.muted
                                    font.pixelSize: 15
                                    font.family: "Symbols Nerd Font"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.family: Theme.fontFamily
                                    clip: true
                                    selectByMouse: true
                                    selectionColor: Theme.accent
                                    property string placeholderText: "Search..."
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: searchInput.placeholderText
                                        color: Theme.muted
                                        font: searchInput.font
                                        visible: !searchInput.text && !searchInput.activeFocus
                                    }
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            root.launcherVisible = false
                                        } else if (event.key === Qt.Key_Down) {
                                            root.selectedIdx = Math.min(root.selectedIdx + 1, root.filteredApps.length - 1)
                                        } else if (event.key === Qt.Key_Up) {
                                            root.selectedIdx = Math.max(root.selectedIdx - 1, 0)
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (root.selectedIdx >= 0 && root.selectedIdx < root.filteredApps.length) {
                                                root.launchApp(root.filteredApps[root.selectedIdx])
                                            }
                                        }
                                    }
                                    onTextChanged: {
                                        root.searchText = text
                                        root.filterApps(text)
                                    }
                                }
                            }
                        }

                        // App list
                        ListView {
                            id: appList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root.filteredApps.length
                            currentIndex: root.selectedIdx
                            clip: true
                            spacing: 2
                            highlightMoveDuration: 0
                            highlightFollowsCurrentItem: true
                            highlight: Rectangle {
                                color: Theme.hover
                                radius: 6
                            }

                            delegate: Rectangle {
                                width: appList.width
                                height: 40
                                color: "transparent"
                                radius: 6

                                property var appEntry: root.filteredApps[index]

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 26; height: 26; radius: 5
                                        color: Theme.surface2
                                        Layout.alignment: Qt.AlignVCenter

                                        IconImage {
                                            id: iconImg
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: appEntry && appEntry.icon ? root.iconSource(appEntry.icon) : ""
                                            onStatusChanged: if (status === Image.Error) visible = false
                                            visible: status === Image.Ready
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: appEntry ? appEntry.name.charAt(0).toUpperCase() : "?"
                                            color: Theme.accent
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                            visible: iconImg.status !== Image.Ready
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: appEntry ? appEntry.name : ""
                                        color: Theme.text
                                        font.pixelSize: 13
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.launchApp(appEntry)
                                    onEntered: root.selectedIdx = index
                                }
                            }
                        }
                    }
                }
            }

            // ══ Volume Popup ════════════════════════════
            PopupWindow {
                id: volPopup
                visible: false
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: bar.width - 160
                anchor.rect.y: bar.height
                implicitWidth: 150
                implicitHeight: 50
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: root.volumePct + "%"
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: 14
                        }
                        Text {
                            text: root.volumeMuted ? "(Muted)" : ""
                            color: Theme.muted
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // ══ Brightness Popup ════════════════════════
            PopupWindow {
                id: brightPopup
                visible: false
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: bar.width - 220
                anchor.rect.y: bar.height
                implicitWidth: 150
                implicitHeight: 50
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.brightnessPct + "%"
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: 14
                    }
                }
            }

            // ══ Token Usage Popup ═══════════════════════
            PopupWindow {
                id: tokenPopup
                visible: root.tokenPopupVisible
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: bar.width - 300
                anchor.rect.y: bar.height
                implicitWidth: 280
                implicitHeight: 160
                color: "transparent"
                onVisibleChanged: { if (!visible) root.tokenPopupVisible = false }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface
                    radius: Theme.radius
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Text {
                            text: "Token Usage"
                            color: Theme.accent
                            font.bold: true
                            font.pixelSize: 13
                        }
                        Rectangle { width: parent.width; height: 1; color: Theme.border }
                        Row { spacing: 8
                            Text { text: "Opencode:"; color: Theme.muted; font.pixelSize: 11 }
                            Text { text: root.tokenSummary; color: Theme.text; font.pixelSize: 11 }
                        }
                        Row { spacing: 8
                            Text { text: "Claude:"; color: Theme.muted; font.pixelSize: 11 }
                            Text { text: "1 session (zen API)"; color: Theme.text; font.pixelSize: 11 }
                        }
                        Row { spacing: 8
                            Text { text: "ZCode:"; color: Theme.muted; font.pixelSize: 11 }
                            Text { text: "installed"; color: Theme.text; font.pixelSize: 11 }
                        }
                        Rectangle { width: parent.width; height: 1; color: Theme.border }
                        Text {
                            text: "Total: " + root.tokenTotal + " tokens"
                            color: Theme.text
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
