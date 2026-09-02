pragma Singleton

import QtQuick

QtObject {
    readonly property color bg: "#111318"
    readonly property color surface: "#1B1E28"
    readonly property color surface2: "#232734"
    readonly property color border: "#2A2F3D"
    readonly property color text: "#E8EAF2"
    readonly property color muted: "#9298AD"
    readonly property color accent: "#7AA2F7"
    readonly property color hover: "#2A2F3D"
    readonly property color pressed: "#232734"

    readonly property int barHeight: 38
    readonly property int radius: 8
    readonly property int pad: 10

    readonly property string fontFamily: "Noto Sans, Inter, sans-serif"
}
