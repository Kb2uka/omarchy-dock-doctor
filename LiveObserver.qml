pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id:root
    readonly property var connection:state
    property int consumers:0
    function acquire() { consumers++ }
    function release() { consumers=Math.max(0,consumers-1);if(!consumers)reconnect.stop() }
    Connection { id:state }
    function send(command) {
        if(!backend.running || !state.fresh) { state.fail("Observer unavailable. Please wait for reconnection.");return }
        backend.write(JSON.stringify(command)+"\n")
    }
    Process {
        id:backend
        command:["/usr/bin/python3","-I",decodeURIComponent(Qt.resolvedUrl("dock-doctor.py").toString().replace(/^file:\/\//,"")),"watch"]
        clearEnvironment:true
        environment:({"HOME":Quickshell.env("HOME"),"XDG_STATE_HOME":Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME")+"/.local/state","PATH":"/usr/bin:/bin","LANG":"C.UTF-8"})
        stdinEnabled:true
        running:root.consumers>0 && !reconnect.running
        stdout:SplitParser { onRead:function(data){state.receive(data)} }
        stderr:SplitParser { onRead:function(data){state.fail(data)} }
        onExited:{state.lost();if(root.consumers>0)reconnect.restart()}
    }
    Timer { id:reconnect; interval:3000 }
    Timer { interval:1000;repeat:true;running:root.consumers>0;onTriggered:state.now=Date.now() }
}
