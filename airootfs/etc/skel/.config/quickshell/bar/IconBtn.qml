import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btn
    property string icon
    property bool dimmed: false
    property bool accented: false
    signal activated()
    signal wheeled(int delta)
    width: 28; height: 20; radius: 4
    color: ma.containsMouse ? "#1e2233" : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
        anchors.centerIn: parent
        text: btn.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: btn.dimmed ? "#767da0" : (btn.accented ? "#96a7f2" : "#c3c8dd")
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
