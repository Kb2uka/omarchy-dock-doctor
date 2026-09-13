import QtQuick
import QtQuick.Controls
import "Palette.js" as P
import "Topology.js" as Graph

Rectangle {
    id: root
    property var devices: []
    property string selectedId: ""
    property bool listMode: false
    signal deviceSelected(string deviceId)
    color: P.surface
    radius: P.radius
    border.color: P.border
    DockText { x:16; y:12; height:30; text:"Connection Tree"; font.pixelSize:16; font.weight:Font.DemiBold }
    Row {
        anchors.right: parent.right; anchors.rightMargin:12; y:10; spacing:4
        DockText { height:32; text:"View:"; color:P.secondary; rightPadding:6 }
        DockButton { objectName:"tree-toggle"; text:"Tree"; quiet:true; implicitWidth:54; implicitHeight:32; highlighted:!root.listMode; onClicked:root.listMode=false; background:Rectangle { radius:7; color:root.listMode ? "transparent" : P.raised; border.color:P.border } }
        DockButton { objectName:"list-toggle"; text:"List"; quiet:true; implicitWidth:54; implicitHeight:32; onClicked:root.listMode=true; background:Rectangle { radius:7; color:root.listMode ? P.raised : "transparent"; border.color:P.border } }
    }
    Flickable {
        id: view
        x:8; y:54; width:parent.width-16; height:parent.height-62
        clip:true
        visible:!root.listMode
        property var graph: Graph.arrange(root.devices,width,height)
        contentWidth:graph.width
        contentHeight:Math.max(height,graph.height)
        function revealSelected() {
            var node=graph.nodes.find(function(n){return n.device.id===root.selectedId})
            if(!node)return
            if(node.y+116>contentY+height) contentY=node.y+116-height
            if(node.y<contentY) contentY=node.y
            if(node.x+132>contentX+width) contentX=node.x+132-width
            if(node.x<contentX) contentX=node.x
        }
        onHeightChanged:Qt.callLater(revealSelected)
        onWidthChanged:Qt.callLater(revealSelected)
        Connections { target:root; function onSelectedIdChanged(){Qt.callLater(view.revealSelected)} }
        ScrollBar.horizontal:ScrollBar { policy:view.contentWidth>view.width?ScrollBar.AlwaysOn:ScrollBar.AlwaysOff }
        ScrollBar.vertical:ScrollBar { policy:view.contentHeight>view.height?ScrollBar.AlwaysOn:ScrollBar.AlwaysOff }
        Canvas {
            id: wires
            width:view.contentWidth; height:view.contentHeight
            property var nodes:view.graph.nodes
            onNodesChanged:requestPaint()
            onWidthChanged:requestPaint()
            onPaint: {
                var c=getContext("2d"); c.reset(); c.strokeStyle="#8fabb5"; c.lineWidth=1
                var byId={}
                nodes.forEach(function(n){byId[n.device.id]=n})
                nodes.forEach(function(n){
                    var p=byId[n.device.parent]; if(!p)return
                    var x=p.x+66, y=p.y+104, xx=n.x+66, yy=n.y+5, mid=(y+yy)/2
                    c.beginPath(); c.moveTo(x,y); c.lineTo(x,mid-6)
                    if(Math.abs(xx-x)>12) { var sign=xx>x?1:-1; c.quadraticCurveTo(x,mid,x+6*sign,mid); c.lineTo(xx-6*sign,mid); c.quadraticCurveTo(xx,mid,xx,mid+6) }
                    c.lineTo(xx,yy); c.stroke()
                    c.fillStyle=n.device.id===root.selectedId?P.gold:"#a0b2ba"
                    c.beginPath(); c.arc(xx,yy,3,0,Math.PI*2); c.fill()
                })
            }
            Connections { target:root; function onSelectedIdChanged(){wires.requestPaint()} }
        }
        Repeater {
            model:view.graph.nodes
            DeviceNode {
                required property var modelData
                objectName:"device-"+modelData.device.id
                x:modelData.x; y:modelData.y
                device:modelData.device
                selected:root.selectedId===device.id
                onClicked:root.deviceSelected(device.id)
            }
        }
    }
    ListView {
        x:12; y:54; width:parent.width-24; height:parent.height-66
        visible:root.listMode
        clip:true
        model:root.devices
        spacing:4
        ScrollBar.vertical:ScrollBar {}
        delegate: ItemDelegate {
            required property var modelData
            width:ListView.view.width; height:54
            onClicked:root.deviceSelected(modelData.id)
            background:Rectangle { radius:5; color:root.selectedId===modelData.id? "#27251b":P.surface; border.color:root.selectedId===modelData.id?P.amber:P.border }
            contentItem: Row {
                spacing:10
                DeviceIcon { width:42; height:36; kind:modelData.kind }
                Column {
                    width:parent.width-62
                    DockText { width:parent.width; text:modelData.name; font.weight:Font.Medium }
                    DockText { width:parent.width; text:P.speed(modelData.speed)+"  ·  "+modelData.category+"  ·  "+(modelData.parent || "Root"); color:P.secondary; font.pixelSize:11 }
                }
            }
        }
    }
    DockText { anchors.centerIn:parent; visible:root.devices.length===0; text:"No USB devices reported"; color:P.secondary }
}
