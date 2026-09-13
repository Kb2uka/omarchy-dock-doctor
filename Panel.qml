import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

Panel {
    id:root
    moduleName:"kb2uka.dock-doctor"
    ipcTarget:"kb2uka.dock-doctor"
    implicitWidth:button.implicitWidth
    implicitHeight:button.implicitHeight
    Connection { id:connection }
    function send(command) {
        if(!backend.running || !connection.fresh) { connection.message="Observer unavailable. Please wait for reconnection.";return }
        backend.write(JSON.stringify(command)+"\n")
    }
    Process {
        id:backend
        command:["/usr/bin/python3","-I",decodeURIComponent(Qt.resolvedUrl("dock-doctor.py").toString().replace(/^file:\/\//,"")),"watch"]
        clearEnvironment:true
        environment:({"HOME":Quickshell.env("HOME"),"XDG_STATE_HOME":Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME")+"/.local/state","PATH":"/usr/bin:/bin","LANG":"C.UTF-8"})
        stdinEnabled:true
        running:true
        stdout:SplitParser { onRead:function(data){connection.receive(data)} }
        stderr:SplitParser { onRead:function(data){connection.message=String(data).slice(0,300)} }
        onExited:{connection.lost();reconnect.restart()}
    }
    Timer { id:reconnect; interval:3000; onTriggered:backend.running=true }
    Timer { interval:1000;repeat:true;running:true;onTriggered:connection.now=Date.now() }
    BarIconButton { id:button; anchors.fill:parent;bar:root.bar;text:"󰕓";onPressed:root.toggle() }
    FloatingWindow {
        id:window
        title:"Dock Doctor"
        visible:root.opened
        implicitWidth:1200
        implicitHeight:800
        minimumSize:Qt.size(1000,700)
        color:"#111619"
        onVisibleChanged:if(!visible && root.opened)root.close()
        DockView {
            anchors.fill:parent
            snapshot:connection.snapshot
            connected:connection.fresh
            backendMessage:connection.message
            onCommandRequested:function(command){root.send(command)}
            onCloseRequested:root.close()
        }
    }
}
