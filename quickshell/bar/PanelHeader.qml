import QtQuick
import QtQuick.Layouts

RowLayout {
    id: ph
    property string title
    Layout.fillWidth: true
    Text { text: ph.title; color: root.dim
        font { family: root.fontName; pixelSize: 11; letterSpacing: 2 } }
    Item { Layout.fillWidth: true }
    Text { text: "×"; color: root.dim; font.pixelSize: 14
        MouseArea { anchors.fill: parent; anchors.margins: -8
            cursorShape: Qt.PointingHandCursor; onClicked: root.closePanel() } }
}
