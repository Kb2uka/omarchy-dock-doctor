import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui as Ui
import "runtime" as Runtime

Ui.Panel {
    id:root
    moduleName:"kb2uka.dock-doctor"
    ipcTarget:"kb2uka.dock-doctor"
    implicitWidth:button.implicitWidth
    implicitHeight:button.implicitHeight
    readonly property var connection:Runtime.LiveObserver.connection
    Component.onCompleted:Runtime.LiveObserver.acquire()
    Component.onDestruction:Runtime.LiveObserver.release()
    Ui.BarIconButton { id:button; objectName:"dock-doctor-badge"; anchors.fill:parent;bar:root.bar;text:"󰕓";onPressed:root.toggle() }
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
            objectName:"dock-doctor-view"
            anchors.fill:parent
            snapshot:connection.snapshot
            connected:connection.fresh
            backendMessage:connection.message
            onCommandRequested:function(command){Runtime.LiveObserver.send(command)}
            onCloseRequested:root.close()
        }
    }
}
