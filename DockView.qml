import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Palette.js" as P
import "Demo.js" as Demo

Rectangle {
    id:root
    color:P.background
    property var snapshot:({devices:[],events:[],baselineAt:"",ready:false,recording:true,error:""})
    property bool connected:false
    property bool demo:false
    property var demoSnapshot:Demo.sample()
    property string page:"Devices"
    property string selectedId:""
    property string message:""
    property bool confirmingBaseline:false
    property bool confirmingClear:false
    readonly property var current:demo?demoSnapshot:snapshot
    readonly property var devices:current.devices || []
    readonly property var selected:devices.find(function(d){return d.id===root.selectedId}) || null
    readonly property bool canWrite:demo || (connected && current.ready && !current.error)
    signal commandRequested(var command)
    signal closeRequested()
    focus:true
    Keys.onEscapePressed:closeRequested()
    function chooseInitial() {
        if(!devices.some(function(d){return d.id===root.selectedId})) {
            var device=devices.find(function(d){return d.kind==="storage"}) || devices.find(function(d){return !d.controller}) || devices[0]
            selectedId=device?device.id:""
        }
    }
    onDevicesChanged:chooseInitial()
    function dispatch(action) {
        confirmingBaseline=false
        if(demo) {
            if(action==="save-baseline") {
                var next=JSON.parse(JSON.stringify(demoSnapshot))
                next.baselineAt=new Date().toISOString()
                next.devices.forEach(function(d){d.baselineSpeed=d.speed;d.comparison="Unchanged"})
                demoSnapshot=next; message="Illustrative baseline saved in memory."
            } else if(action==="export") message="Demo report preview only. Switch to live devices to export a real report."
            return
        }
        commandRequested({action:action})
    }
    Rectangle {
        id:sidebar
        width:root.width<1100?164:188; height:parent.height
        color:P.sidebar
        Rectangle { anchors.right:parent.right; width:1; height:parent.height; color:P.border }
        DeviceIcon { x:18; y:22; width:34; height:38; kind:"usb"; ink:P.gold }
        DockText { x:22; y:65; text:"Dock Doctor"; font.pixelSize:22; font.weight:Font.DemiBold }
        DockText { x:22; y:96; width:parent.width-28; text:"Understand your connections"; font.pixelSize:10; color:P.secondary }
        Column {
            x:12; y:146; width:parent.width-13; spacing:2
            Repeater {
                model:[["Devices","▱"],["Compare","⇄"],["Event Log","▤"],["Settings","⚙"]]
                delegate: AbstractButton {
                    required property var modelData
                    objectName:"nav-"+modelData[0]
                    width:parent.width; height:40; hoverEnabled:true
                    onClicked:root.page=modelData[0]
                    background:Rectangle {
                        color:root.page===modelData[0]?P.raised:parent.hovered?"#172024":"transparent"
                        radius:5
                        border.color:parent.activeFocus?P.amber:"transparent"
                        Rectangle { width:2; height:parent.height-8; y:4; color:P.gold; visible:root.page===modelData[0] }
                    }
                    contentItem:Row {
                        leftPadding:13; spacing:13
                        DockText { text:modelData[1]; width:20; height:40; font.pixelSize:20; color:P.secondary }
                        DockText { text:modelData[0]; height:40; color:root.page===modelData[0]?P.text:P.secondary; font.pixelSize:12 }
                    }
                }
            }
        }
        Column {
            x:22; width:parent.width-44; anchors.bottom:parent.bottom; anchors.bottomMargin:26; spacing:12
            Rectangle { width:parent.width; height:1; color:"#394349" }
            DockText { width:parent.width; text:"USB made simple\nfor a more connected day."; color:P.secondary; font.pixelSize:10; lineHeight:1.6; wrapMode:Text.WordWrap }
        }
    }
    ColumnLayout {
        x:sidebar.width+14; y:14
        width:parent.width-sidebar.width-28; height:parent.height-28; spacing:12
        RowLayout {
            Layout.fillWidth:true; Layout.preferredHeight:64; spacing:8
            Repeater {
                model:[
                    [String(root.devices.filter(function(d){return !d.controller}).length),"devices connected","▱"],
                    [String((root.current.events||[]).length),"connection events","⌁"],
                    ["Baseline:",P.date(root.current.baselineAt),"◷"]
                ]
                Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth:true; Layout.preferredWidth:index===2?162:142; Layout.preferredHeight:64
                    color:P.surface; radius:6; border.color:P.border
                    DockText { x:12; y:13; height:32; width:25; text:modelData[2]; font.pixelSize:25; color:P.secondary; visible:parent.width>130 }
                    Column {
                        x:parent.width>130?43:10; y:10; width:parent.width-x-8; spacing:4
                        DockText { text:modelData[0]; width:parent.width; font.pixelSize:index===2?11:23; font.weight:index===2?Font.Normal:Font.Medium; color:index===2?P.secondary:P.text }
                        DockText { text:modelData[1]; width:parent.width; color:P.secondary; font.pixelSize:10 }
                    }
                }
            }
            Rectangle { Layout.preferredWidth:1; Layout.preferredHeight:54; color:P.border; Layout.leftMargin:5; Layout.rightMargin:5 }
            DockButton { objectName:"save-baseline"; text:root.width<1100?"Save Baseline":"↓  Save Baseline"; primary:true; enabled:root.canWrite; onClicked: { if(root.current.baselineAt)root.confirmingBaseline=true; else root.dispatch("save-baseline") } }
            DockButton { objectName:"compare"; text:"Compare"; onClicked:root.page="Compare" }
            DockButton { objectName:"export"; text:root.width<1100?"Export":"Export Report"; enabled:root.demo || root.connected; onClicked:root.dispatch("export") }
        }
        Rectangle {
            Layout.fillWidth:true; Layout.preferredHeight:28
            visible:root.demo || !root.connected || !!root.current.error || root.message!==""
            color:root.current.error?"#30231d":"#19252d"; border.color:root.current.error?"#795338":"#314752"; radius:4
            DockText {
                x:10; width:parent.width-20; height:parent.height; font.pixelSize:10
                text:root.demo?"Illustrative demo · These readings are not your hardware.  "+root.message:!root.connected?"Observer disconnected. Displayed readings may be stale.":root.current.error || root.message
                color:root.current.error?P.gold:P.secondary
            }
        }
        RowLayout {
            visible:root.page==="Devices"
            Layout.fillWidth:true; Layout.fillHeight:true; spacing:10
            TopologyPanel { id:topology; objectName:"topology"; Layout.fillWidth:true; Layout.fillHeight:true; Layout.preferredWidth:650; devices:root.devices; selectedId:root.selectedId; onDeviceSelected:function(deviceId){root.selectedId=deviceId} }
            Inspector { objectName:"inspector"; Layout.fillHeight:true; Layout.preferredWidth:Math.max(280,(root.width-sidebar.width-38)*0.32); device:root.selected; devices:root.devices }
        }
        EventsPanel {
            visible:root.page==="Devices" || root.page==="Event Log"
            Layout.fillWidth:true; Layout.fillHeight:root.page==="Event Log"; Layout.preferredHeight:root.page==="Devices"?224:500
            events:root.current.events || []; observation:root.current.observation || ""; expanded:root.page==="Event Log"
        }
        ComparePanel { visible:root.page==="Compare"; Layout.fillWidth:true; Layout.fillHeight:true; devices:root.devices.concat(root.current.missingDevices || []); baselineAt:root.current.baselineAt || "" }
        Rectangle {
            visible:root.page==="Settings"
            Layout.fillWidth:true; Layout.fillHeight:true; color:P.surface; radius:8; border.color:P.border
            Column {
                x:24; y:22; width:parent.width-48; spacing:18
                DockText { text:"Settings"; font.pixelSize:20; font.weight:Font.DemiBold }
                DockText { width:parent.width; text:"Connection history"; font.pixelSize:14; font.weight:Font.DemiBold }
                DockText { width:parent.width; text:"Record observed USB changes while the plugin is enabled. The latest 300 events are retained locally. Events while disabled or between scans may be missed."; color:P.secondary; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                DockButton {
                    objectName:"recording-toggle"; text:root.current.recording?"Pause recording":"Resume recording"; quiet:true; enabled:!root.demo&&root.canWrite
                    onClicked:root.commandRequested({action:"recording",enabled:!root.current.recording})
                }
                DockButton { objectName:"clear-events"; text:"Clear event history"; quiet:true; enabled:!root.demo&&root.canWrite; onClicked:root.confirmingClear=true }
                Rectangle { width:parent.width; height:1; color:P.border }
                DockText { text:"Reports & privacy"; font.pixelSize:14; font.weight:Font.DemiBold }
                DockText { width:parent.width; text:"Reports are saved locally and include device names, USB IDs, link speeds, and event history. Serial-number fields and identity keys are excluded. Review a report before sharing it. Nothing is uploaded."; color:P.secondary; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                Rectangle { width:parent.width; height:1; color:P.border }
                DockText { text:"Design preview"; font.pixelSize:14; font.weight:Font.DemiBold }
                DockText { width:parent.width; text:"Explore the interface with illustrative readings. Demo actions stay in memory and never replace your live baseline."; color:P.secondary; wrapMode:Text.WordWrap; elide:Text.ElideNone }
                DockButton { objectName:"demo-toggle"; text:root.demo?"Return to live devices":"Open illustrative demo"; quiet:true; onClicked:{root.demo=!root.demo;root.message="";root.page="Devices";root.selectedId="";root.chooseInitial()} }
            }
        }
    }
    Popup {
        id:confirmation
        anchors.centerIn:parent; width:400; padding:22; modal:true
        visible:root.confirmingBaseline || root.confirmingClear
        closePolicy:Popup.CloseOnEscape
        onClosed:{root.confirmingBaseline=false;root.confirmingClear=false}
        background:Rectangle { color:P.surface; border.color:P.border; radius:8 }
        contentItem:Column {
            spacing:18
            DockText { width:parent.width; text:root.confirmingClear?"Clear recorded events?":"Replace your working baseline?"; font.pixelSize:17; font.weight:Font.DemiBold; wrapMode:Text.WordWrap }
            DockText { width:parent.width; text:root.confirmingClear?"This removes the retained event history. Your baseline stays intact.":"Save only when your setup is working as expected. The current baseline will be replaced."; color:P.secondary; wrapMode:Text.WordWrap; elide:Text.ElideNone }
            Row {
                spacing:10
                DockButton { text:"Cancel"; quiet:true; onClicked:{root.confirmingBaseline=false;root.confirmingClear=false} }
                DockButton { text:root.confirmingClear?"Clear events":"Save Baseline"; primary:true; onClicked:{if(root.confirmingClear){root.commandRequested({action:"clear-events"});root.confirmingClear=false}else root.dispatch("save-baseline")} }
            }
        }
    }
}
