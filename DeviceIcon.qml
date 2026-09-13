import QtQuick
import "Palette.js" as P

Canvas {
    id: root
    property string kind: "device"
    property color ink: "#c3c8c8"
    implicitWidth: 64
    implicitHeight: 48
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d")
        c.reset()
        c.scale(width / 80, height / 60)
        c.strokeStyle = ink
        c.fillStyle = "#242b2f"
        c.lineWidth = 1.7
        c.lineJoin = "round"
        function rect(x,y,w,h) { c.beginPath(); c.rect(x,y,w,h); c.fill(); c.stroke() }
        function line(x,y,xx,yy) { c.beginPath(); c.moveTo(x,y); c.lineTo(xx,yy); c.stroke() }
        function circle(x,y,r) { c.beginPath(); c.arc(x,y,r,0,Math.PI*2); c.fill(); c.stroke() }
        if (kind === "settings") {
            c.reset(); c.scale(width/60,height/60)
            c.strokeStyle=ink; c.fillStyle=P.surface; c.lineWidth=2.5; c.lineJoin="round"
            c.beginPath()
            for (var tooth=0;tooth<32;tooth++) {
                var angle=tooth*Math.PI/16
                var radius=(tooth%4===0 || tooth%4===3)?23:18
                var px=30+Math.cos(angle)*radius, py=30+Math.sin(angle)*radius
                if(tooth===0)c.moveTo(px,py);else c.lineTo(px,py)
            }
            c.closePath();c.fill();c.stroke();circle(30,30,8)
        } else if (kind === "laptop") {
            rect(14,6,52,37); line(19,12,61,12)
            c.beginPath(); c.moveTo(14,43); c.lineTo(7,49); c.lineTo(73,49); c.lineTo(66,43); c.closePath(); c.fill(); c.stroke()
            line(30,49,50,49)
        } else if (kind === "controller") {
            rect(23,13,34,34); rect(31,21,18,18)
            for (var pin=0;pin<4;pin++) {
                var offset=27+pin*8
                line(offset,7,offset,13); line(offset,47,offset,53)
                line(17,17+pin*8,23,17+pin*8); line(57,17+pin*8,63,17+pin*8)
            }
        } else if (kind === "hub") {
            rect(6,20,68,27); line(7,25,73,25)
            c.strokeStyle = "#7991a0"
            for (var i=0;i<4;i++) { c.fillStyle="#163b53"; rect(23+i*10,32,5,5) }
        } else if (kind === "audio") {
            rect(16,15,48,36); line(19,21,61,21)
            circle(42,35,10); c.fillStyle="#13191d"; circle(42,35,5)
            c.fillStyle="#49768b"; circle(24,29,2); circle(24,42,2)
            c.fillStyle="#242b2f"; line(21,15,27,10); line(27,10,60,10); line(60,10,64,15)
        } else if (kind === "camera") {
            circle(40,27,17); c.fillStyle="#111619"; circle(40,27,11)
            c.strokeStyle="#698290"; circle(40,27,5)
            c.strokeStyle=ink; line(40,45,40,49); line(26,50,54,50)
        } else if (kind === "keyboard") {
            rect(4,18,72,30)
            c.lineWidth=1
            for (var r=0;r<3;r++) for (var k=0;k<12;k++) c.strokeRect(9+k*5.2,23+r*6,2.5,2.5)
            line(29,44,51,44)
        } else if (kind === "storage") {
            c.beginPath(); c.moveTo(22,12); c.lineTo(48,12); c.lineTo(62,47); c.lineTo(34,47); c.closePath(); c.fill(); c.stroke()
            line(27,18,45,18); line(35,42,55,42)
        } else if (kind === "usb") {
            rect(29,19,22,24); c.strokeRect(33,8,14,11); line(36,12,36,15); line(44,12,44,15)
            line(36,43,36,49); line(44,43,44,49); line(36,49,40,54); line(44,49,40,54)
        } else {
            rect(25,10,30,41); line(31,16,49,16); circle(40,44,2)
        }
    }
}
