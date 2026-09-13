import QtQuick

QtObject {
    id:root
    property var snapshot:({devices:[],events:[],baselineAt:"",ready:false,recording:true,error:""})
    property bool alive:false
    property string message:""
    property bool connectionError:false
    property double lastReceived:0
    property double now:Date.now()
    readonly property bool fresh:alive && now-lastReceived<6500
    function fail(text) {
        alive=false;connectionError=true;message=String(text).slice(0,300)
    }
    function receive(line) {
        if(line.length>1048576){lost();return}
        try {
            var data=JSON.parse(line)
            if(data.kind==="snapshot" && Array.isArray(data.devices) && data.devices.length<=256 && Array.isArray(data.events) && data.events.length<=300) {
                if(connectionError){message="";connectionError=false}
                snapshot=data;lastReceived=Date.now();now=lastReceived;alive=true
            } else if(data.kind==="result") { message=String(data.message || "");connectionError=false }
        } catch(e) { fail("Unreadable observer response") }
    }
    function lost() { fail("Observer stopped. Reconnecting…") }
}
