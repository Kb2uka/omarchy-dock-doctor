import QtQuick
import QtQuick.Controls
import "Palette.js" as P

Rectangle {
    id:root
    property var device:null
    property var devices:[]
    signal compareRequested()
    readonly property string parentName: { var p=devices.find(function(d){return root.device && d.id===root.device.parent}); return p?p.name:"Not reported" }
    color:P.surface; radius:P.radius; border.color:P.border
    ScrollView {
        anchors.fill:parent; anchors.margins:16; clip:true
        contentWidth:availableWidth
        Column {
            width:parent.width; spacing:12
            Row {
                width:parent.width; spacing:10
                DeviceIcon { width:42; height:48; kind:root.device ? root.device.kind:"device" }
                Column {
                    width:parent.width-84; spacing:5
                    DockText { width:parent.width; text:root.device?root.device.name:"Select a device"; font.pixelSize:17; font.weight:Font.DemiBold; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                    DockText { width:parent.width; text:root.device?root.device.category:"Explore the connection tree"; color:P.secondary; wrapMode:Text.WordWrap }
                }
                DockButton {
                    objectName:"device-menu"; text:"⋯"; quiet:true; implicitWidth:22; implicitHeight:28; padding:0
                    Accessible.name:"Device actions"
                    enabled:root.device!==null
                    onClicked:deviceMenu.open()
                    DockMenu {
                        id:deviceMenu; objectName:"device-actions-menu"
                        MenuItem { objectName:"device-compare-action"; text:"Compare with baseline"; onTriggered:root.compareRequested() }
                    }
                }
            }
            Column {
                width:parent.width; spacing:9
                Repeater {
                    model: [
                        ["Current link:", root.device?P.speed(root.device.speed):"Not reported",true],
                        ["Saved baseline:", root.device?P.speed(root.device.baselineSpeed):"Not reported",true],
                        ["Connected through:",root.parentName,true],
                        ["USB device ID:",root.device&&root.device.vendor?root.device.vendor+":"+root.device.productId:"Not reported",false],
                        ["Product:",root.device?P.reported(root.device.product):"Not reported",false]
                    ]
                    Row {
                        required property var modelData
                        width:parent.width; spacing:8
                        DockText { width:parent.width*0.49; text:modelData[0]; color:P.secondary; font.pixelSize:11 }
                        DockText { width:parent.width*0.51-8; text:modelData[1]; font.pixelSize:11; font.weight:modelData[2]?Font.Medium:Font.Normal; color:modelData[2]?P.text:P.secondary; wrapMode:Text.WrapAnywhere; elide:Text.ElideNone }
                    }
                }
            }
            Rectangle { width:parent.width; height:1; color:P.border }
            Rectangle {
                width:parent.width; height:warning.implicitHeight+24
                visible:root.device && root.device.comparison==="Lower link speed"
                color:"#29261b"; border.color:"#79602e"; radius:6
                Row {
                    id:warning; x:12; y:12; width:parent.width-24; spacing:9
                    Rectangle { width:20; height:20; radius:10; color:P.gold; DockText { anchors.fill:parent; horizontalAlignment:Text.AlignHCenter; text:"!"; font.bold:true; color:P.sidebar; font.pixelSize:14 } }
                    Column {
                        width:parent.width-29; spacing:8
                        DockText { width:parent.width; text:"Link speed is lower than your saved baseline."; color:P.gold; font.weight:Font.DemiBold; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                        DockText { width:parent.width; text:"Try another cable or port, then compare again."; color:P.secondary; font.pixelSize:11; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                    }
                }
            }
            Rectangle { width:parent.width; height:1; color:P.border }
            Column {
                width:parent.width; spacing:10
                DockText { text:"Device information"; color:P.secondary; font.pixelSize:11 }
                Repeater {
                    model:[["Manufacturer:","manufacturer"],["Model:","product"],["Serial number:","serial"]]
                    Row {
                        required property var modelData
                        width:parent.width; spacing:8
                        DockText { width:parent.width*0.49; text:modelData[0]; color:P.secondary; font.pixelSize:11 }
                        DockText { width:parent.width*0.51-8; text:root.device?P.reported(root.device[modelData[1]]):"Not reported"; color:P.secondary; font.pixelSize:11; wrapMode:Text.WrapAnywhere; elide:Text.ElideNone }
                    }
                }
            }
            DockText {
                width:parent.width; color:P.muted; font.pixelSize:10; wrapMode:Text.WordWrap; elide:Text.ElideNone
                text:root.device && root.device.ambiguous ? "Identity is ambiguous. Baseline comparison is unavailable." : root.device && root.device.matchBasis==="port" ? "Matched by USB port and device ID. Identical replacements cannot be distinguished." : "Negotiated link speed is not file-transfer throughput."
            }
        }
    }
}
