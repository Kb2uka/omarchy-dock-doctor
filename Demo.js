.pragma library
function sample() {
    var devices = [
        {id:"usb1",parent:"",name:"Omarchy Laptop",kind:"laptop",category:"USB 3.1 Host Controller",speed:5000,controller:true},
        {id:"1-1",parent:"usb1",name:"Desk Hub",kind:"hub",category:"USB Hub",speed:5000},
        {id:"1-1.1",parent:"1-1",name:"RME Babyface Pro",kind:"audio",category:"Audio Interface",speed:480},
        {id:"1-1.2",parent:"1-1",name:"Webcam",kind:"camera",category:"USB Camera",speed:480},
        {id:"1-1.3",parent:"1-1",name:"External SSD",kind:"storage",category:"Mass Storage",speed:480,baselineSpeed:5000},
        {id:"1-1.4",parent:"1-1",name:"Keyboard",kind:"keyboard",category:"HID Keyboard",speed:12}
    ]
    devices.forEach(function(d) {
        d.key=d.id; d.serial=""; d.vendor=""; d.productId=""; d.product=""; d.manufacturer=""
        d.identityBasis="port"; d.matchBasis="port"; d.ambiguous=false
        d.baselineSpeed=d.baselineSpeed || d.speed
        d.comparison=d.speed<d.baselineSpeed ? "Lower link speed" : "Unchanged"
    })
    return {ready:true,devices:devices,baselineAt:"2026-09-12T18:42:00",recording:true,error:"",
        observation:"Both devices share Desk Hub.",events:[
            {at:"2026-09-13T10:42:03",type:"disconnect",event:"Webcam disconnected",details:"USB Camera (via Desk Hub)",parent:"1-1"},
            {at:"2026-09-13T10:42:03",type:"disconnect",event:"Babyface disconnected",details:"RME Babyface Pro (via Desk Hub)",parent:"1-1"},
            {at:"2026-09-13T10:42:05",type:"connect",event:"Both devices reconnected",details:"Webcam and Babyface Pro (via Desk Hub)",parent:"1-1"}]}
}
