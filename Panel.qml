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
    readonly property var connection:LiveObserver.connection
    Component.onCompleted:LiveObserver.acquire()
    Component.onDestruction:LiveObserver.release()
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
            onCommandRequested:function(command){LiveObserver.send(command)}
            onCloseRequested:root.close()
        }
    }
}
