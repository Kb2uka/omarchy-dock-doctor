import QtQuick

QtObject {
    id:root
    property var snapshot:({devices:[],events:[],baselineAt:"",ready:false,recording:true,error:""})
    property bool alive:false
    property string message:""
    property double lastReceived:0
    property double now:Date.now()
    readonly property bool fresh:alive && now-lastReceived<6500
    function receive(line) {
        if(line.length>1048576){lost();return}
        try {
            var data=JSON.parse(line)
            if(data.kind==="snapshot" && Array.isArray(data.devices) && data.devices.length<=256 && Array.isArray(data.events) && data.events.length<=300) {
                if(!alive)message=""
                snapshot=data;lastReceived=Date.now();now=lastReceived;alive=true
            } else if(data.kind==="result") message=String(data.message || "")
        } catch(e) { message="Unreadable observer response";alive=false }
    }
    function lost() { alive=false;message="Observer stopped. Reconnecting…" }
}
