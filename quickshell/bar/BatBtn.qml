import QtQuick
import QtQuick.Layouts

Rectangle {
    id: bb
    width: 48; height: 20; radius: 4
    color: bma.containsMouse ? "#1e2233" : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }
    Row {
        anchors.centerIn: parent
        spacing: 5
        Text {
            text: root.batIcon
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
            color: root.batAlert ? root.red : (root.batCharging || root.batIsFull) ? root.green : root.fg
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.batCap + "%"
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
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
    }
}
