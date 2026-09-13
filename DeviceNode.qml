import QtQuick
import QtQuick.Controls
import "Palette.js" as P

AbstractButton {
    id: root
    property var device: ({})
    property bool selected: false
    width: 132
    height: 116
    hoverEnabled: true
    Accessible.name: device.name || "USB device"
    background: Rectangle {
        radius: 7
        color: root.selected ? "#27251b" : root.hovered ? "#20282b" : "transparent"
        border.color: root.selected || root.activeFocus ? P.gold : "transparent"
    }
    contentItem: Column {
        spacing: 4
        DeviceIcon { anchors.horizontalCenter: parent.horizontalCenter; kind: root.device.kind || "device"; width: 62; height: 46 }
        DockText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.device.name || ""; font.weight: Font.DemiBold }
        DockText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.device.controller ? root.device.category : P.speed(root.device.speed); color: P.secondary; font.pixelSize: 11 }
        DockText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.device.controller ? "" : root.device.category || ""; color: P.secondary; font.pixelSize: 11 }
    }
    ToolTip {
        visible:root.hovered
        delay:800
        contentItem:DockText { text:root.device.name || ""; wrapMode:Text.WordWrap }
    }
}
