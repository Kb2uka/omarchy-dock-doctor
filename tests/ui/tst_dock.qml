import QtQuick
import QtTest
import "../.." as Dock
import "../../Demo.js" as Demo
import "../../Topology.js" as Graph

Item {
    id:stage
    width:1200; height:800
    Dock.DockView { id:view; anchors.fill:parent; backendMessage:connection.message }
    Dock.Connection { id:connection }
    SignalSpy { id:commands; target:view; signalName:"commandRequested" }
    TestCase {
        name:"DockDoctor"
        when:windowShown
        function init() {
            stage.width=1200;stage.height=800
            view.demo=false;view.snapshot=Demo.sample();view.connected=true
            view.demoSnapshot=Demo.sample();view.selectedId="1-1.3"
            view.page="Devices";connection.message="";view.demoMessage="";view.confirmingBaseline=false;view.confirmingClear=false
            findChild(view,"topology").listMode=false
            findChild(view,"event-filter-menu").close()
            findChild(view,"device-actions-menu").close()
            commands.clear()
            wait(50)
        }
        function test_captureReference() {
            view.demo=true
            wait(150)
            grabImage(view).save(Qt.resolvedUrl("../../.artifacts/feat_dock_doctor/interface-1200.png").toString().replace("file://", ""))
            stage.width=1536;stage.height=960
            wait(150)
            grabImage(view).save(Qt.resolvedUrl("../../.artifacts/feat_dock_doctor/interface-1536.png").toString().replace("file://", ""))
            stage.width=1000;stage.height=700
            wait(150)
            grabImage(view).save(Qt.resolvedUrl("../../.artifacts/feat_dock_doctor/interface-1000.png").toString().replace("file://", ""))
        }
        function test_deviceSelectionUpdatesInspector() {
            mouseClick(findChild(view,"device-1-1.2"))
            compare(view.selected.name,"Webcam")
            compare(findChild(view,"inspector").device.name,"Webcam")
        }
        function test_treeListToggle() {
            mouseClick(findChild(view,"list-toggle"))
            compare(findChild(view,"topology").listMode,true)
            mouseClick(findChild(view,"tree-toggle"))
            compare(findChild(view,"topology").listMode,false)
        }
        function test_inspectorMenuOpensComparison() {
            mouseClick(findChild(view,"device-menu"))
            var menu=findChild(view,"device-actions-menu")
            tryCompare(menu,"opened",true)
            compare(menu.count,1)
            verify(menu.itemAt(0).width>0,"Menu item width: "+menu.itemAt(0).width)
            mouseClick(menu.itemAt(0))
            tryCompare(view,"page","Compare")
        }
        function test_eventDropdownFiltersRows() {
            mouseClick(findChild(view,"event-filter"))
            var menu=findChild(view,"event-filter-menu")
            tryCompare(menu,"opened",true)
            compare(menu.count,4)
            verify(menu.itemAt(1).width>0,"Menu item width: "+menu.itemAt(1).width)
            mouseClick(menu.itemAt(1))
            var panel=findChild(view,"events-panel")
            tryCompare(panel,"filter","Disconnects")
            compare(panel.filtered.length,2)
            verify(panel.filtered.every(function(e){return e.type==="disconnect"}))
            panel.filter="All Events"
        }
        function test_navigationAndCompare() {
            mouseClick(findChild(view,"compare"))
            compare(view.page,"Compare")
            mouseClick(findChild(view,"nav-Event Log"))
            compare(view.page,"Event Log")
            mouseClick(findChild(view,"nav-Settings"))
            compare(view.page,"Settings")
        }
        function test_saveNeedsConfirmationAndNoImplicitMutation() {
            mouseClick(findChild(view,"save-baseline"))
            verify(view.confirmingBaseline)
            compare(commands.count,0)
            view.confirmingBaseline=false
            view.dispatch("save-baseline")
            compare(commands.count,1)
            compare(commands.signalArguments[0][0].action,"save-baseline")
        }
        function test_demoSaveIsIsolated() {
            view.demo=true
            view.dispatch("save-baseline")
            compare(commands.count,0)
            compare(view.demoSnapshot.devices[4].baselineSpeed,480)
            compare(view.snapshot.devices[4].baselineSpeed,5000)
        }
        function test_demoReturnPreservesLiveMessages() {
            view.page="Settings"
            mouseClick(findChild(view,"demo-toggle"))
            verify(view.demo)
            view.page="Settings"
            mouseClick(findChild(view,"demo-toggle"))
            verify(!view.demo)
            connection.receive(JSON.stringify({kind:"result",message:"Report saved: private.json"}))
            compare(view.message,"Report saved: private.json")
        }
        function test_exportInvokesRealCommand() {
            mouseClick(findChild(view,"export"))
            compare(commands.count,1)
            compare(commands.signalArguments[0][0].action,"export")
        }
        function test_disconnectDisablesWrites() {
            view.connected=false
            verify(!findChild(view,"save-baseline").enabled)
            verify(!findChild(view,"export").enabled)
        }
        function test_backendFreshness() {
            connection.receive(JSON.stringify(Object.assign({kind:"snapshot"},Demo.sample())))
            verify(connection.fresh)
            connection.now=connection.lastReceived+6500
            verify(!connection.fresh)
            connection.lost()
            verify(!connection.alive)
        }
        function test_reconnectClearsOnlyConnectionError() {
            connection.lost()
            connection.receive(JSON.stringify({kind:"snapshot",devices:[],events:[]}))
            compare(connection.message,"")
            connection.receive(JSON.stringify({kind:"result",message:"Working baseline saved"}))
            connection.receive(JSON.stringify({kind:"snapshot",devices:[],events:[]}))
            compare(connection.message,"Working baseline saved")
        }
        function test_resultSurvivesRecoverySnapshot() {
            connection.receive("malformed")
            connection.receive(JSON.stringify({kind:"result",message:"Report saved: private.json"}))
            connection.receive(JSON.stringify({kind:"snapshot",devices:[],events:[]}))
            compare(connection.message,"Report saved: private.json")
        }
        function test_emptyInventoryAndHostileName() {
            var d=Demo.sample()
            d.devices[4].name="<img src='file:///etc/passwd'>"
            view.snapshot=d
            compare(view.selected.name,d.devices[4].name)
            view.snapshot={devices:[],events:[],ready:true}
            compare(view.selected,null)
        }
        function test_graphSupportsNestedAndMultipleRoots() {
            var d=Demo.sample().devices
            d.push({id:"usb2",parent:"",name:"Other root"})
            d.push({id:"2-1",parent:"usb2",name:"Other device"})
            var g=Graph.arrange(d,600)
            compare(g.nodes.length,d.length)
            verify(g.width>=600)
            var positions={}
            g.nodes.forEach(function(n){verify(!positions[n.x+","+n.y]);positions[n.x+","+n.y]=true})
        }
        function test_graphCycleIsBounded() {
            var g=Graph.arrange([{id:"a",parent:"b"},{id:"b",parent:"a"}],600)
            compare(g.nodes.length,2)
        }
    }
}
