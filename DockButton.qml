import QtQuick
import QtQuick.Controls
import "Palette.js" as P

Button {
    id: root
    property bool primary: false
    property bool quiet: false
    implicitHeight: 38
    implicitWidth: Math.max(82, label.implicitWidth + 28)
    padding: 10
    hoverEnabled: true
    contentItem: DockText {
        id: label
        text: root.text
        color: root.primary ? "#16191a" : root.enabled ? P.text : P.muted
        font.weight: root.primary ? Font.DemiBold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
    }
    background: Rectangle {
        radius: 6
        color: root.primary ? (root.down ? P.amber : P.gold) : root.down || root.hovered ? P.raised : "transparent"
        border.width: 1
        border.color: root.activeFocus ? P.amber : root.primary ? P.gold : root.quiet ? P.border : "#aaa69a"
        opacity: root.enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
