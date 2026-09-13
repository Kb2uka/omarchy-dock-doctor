import QtQuick
import QtQuick.Controls
import "Palette.js" as P

Rectangle {
    id:root
    property var devices:[]
    property string baselineAt:""
    color:P.surface; border.color:P.border; radius:P.radius
    Column {
        x:20; y:16; width:parent.width-40; spacing:8
        DockText { text:"Baseline comparison"; font.pixelSize:18; font.weight:Font.DemiBold }
        DockText { width:parent.width; text:root.baselineAt?"Saved "+P.date(root.baselineAt)+". Only identifiable devices are compared.":"Save a working baseline from Devices to start a comparison."; color:P.secondary; wrapMode:Text.WordWrap }
        DockText { width:parent.width; text:"Link speeds describe the negotiated USB connection. They do not measure transfer performance or device health."; color:P.muted; font.pixelSize:11; wrapMode:Text.WordWrap }
    }
    ListView {
        x:16; y:108; width:parent.width-32; height:parent.height-124
        clip:true; spacing:6; model:root.devices.filter(function(d){return !d.controller})
        ScrollBar.vertical:ScrollBar {}
        delegate: Rectangle {
            required property var modelData
            width:ListView.view.width; height:78; color:"#1b2226"; border.color:P.border; radius:6
            DeviceIcon { x:12; y:15; width:50; height:44; kind:modelData.kind }
            Column {
                x:76; y:13; width:parent.width-90; spacing:6
                DockText { text:modelData.name; width:parent.width; font.weight:Font.DemiBold; font.pixelSize:14 }
                DockText { width:parent.width; text:P.speed(modelData.baselineSpeed)+"  →  "+P.speed(modelData.speed)+"     "+modelData.comparison; color:modelData.comparison==="Lower link speed"?P.gold:P.secondary }
            }
        }
    }
}
