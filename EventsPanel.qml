import QtQuick
import QtQuick.Controls
import "Palette.js" as P

Rectangle {
    id:root
    property var events:[]
    property string observation:""
    property bool expanded:false
    property string filter:"All Events"
    readonly property var filtered:events.filter(function(e){return root.filter==="All Events" || e.type===(root.filter==="Disconnects"?"disconnect":root.filter==="Connections"?"connect":"change")})
    color:P.surface; border.color:P.border; radius:P.radius
    DockText { x:16; y:12; height:28; text:root.expanded?"Event Log":"Recent Events"; font.pixelSize:16; font.weight:Font.DemiBold }
    DockButton {
        id:filterButton; objectName:"event-filter"; anchors.right:parent.right; anchors.rightMargin:16; y:10
        text:root.filter+"  ⌄"; quiet:true; implicitHeight:30
        onClicked:filterMenu.open()
        Menu {
            id:filterMenu; y:filterButton.height
            Repeater { model:["All Events","Disconnects","Connections","Link changes"]; MenuItem { required property string modelData; text:modelData; onTriggered:root.filter=modelData } }
        }
    }
    Flickable {
        id:table
        x:16; y:48; width:parent.width-32; height:parent.height-62-(root.observation?42:0)
        contentWidth:Math.max(width,720)
        contentHeight:Math.max(height,26+eventColumn.height)
        clip:true
        ScrollBar.horizontal:ScrollBar {}
        ScrollBar.vertical:ScrollBar {}
        Row {
            width:table.contentWidth; height:24
            DockText { width:90; text:"Time"; color:P.secondary; font.pixelSize:11 }
            DockText { width:table.contentWidth*0.43-90; text:"Event"; color:P.secondary; font.pixelSize:11 }
            DockText { text:"Details"; color:P.secondary; font.pixelSize:11 }
        }
        Rectangle { y:25; width:table.contentWidth; height:1; color:"#394349" }
        Column {
            id:eventColumn; y:26; width:table.contentWidth
            Repeater {
                model:root.expanded?root.filtered.slice().reverse():root.filtered.slice(-3)
                Item {
                    required property var modelData
                    width:eventColumn.width; height:30
                    DockText { x:2; height:29; width:75; text:Qt.formatTime(new Date(modelData.at),"HH:mm:ss"); color:P.secondary; font.pixelSize:11 }
                    DockText { x:87; height:29; width:22; text:modelData.type==="disconnect"?"×":modelData.type==="connect"?"+":"↔"; font.pixelSize:18; color:modelData.type==="disconnect"?P.orange:modelData.type==="connect"?P.green:P.blue }
                    DockText { x:113; height:29; width:parent.width*0.43-121; text:modelData.event; font.pixelSize:11 }
                    DockText { x:parent.width*0.43; height:29; width:parent.width*0.57-8; text:modelData.details; color:P.secondary; font.pixelSize:11 }
                    Rectangle { y:29; width:parent.width; height:1; color:P.border; opacity:0.65 }
                }
            }
        }
        DockText { y:45; width:table.width; horizontalAlignment:Text.AlignHCenter; text:"No recorded events match this filter."; color:P.muted; visible:root.filtered.length===0 }
    }
    Rectangle {
        visible:root.observation!==""
        x:16; width:parent.width-32; height:36; anchors.bottom:parent.bottom; anchors.bottomMargin:12
        radius:5; color:"#1b252d"; border.color:"#334b61"
        DockText { x:12; width:parent.width-24; height:parent.height; text:"ⓘ   Observation:  "+root.observation; font.pixelSize:11 }
    }
}
