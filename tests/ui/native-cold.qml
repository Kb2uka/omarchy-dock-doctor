import QtQuick
import Quickshell

ShellRoot {
    id: root
    property var pluginComponent: null
    property int ticks: 0
    property int phase: 0
    property string observedAt: ""
    Loader { id: first; sourceComponent: root.pluginComponent }
    Loader { id: second; sourceComponent: root.pluginComponent }

    function named(object, name) {
        if (!object) return null
        if (object.objectName === name) return object
        var children = object.data || object.children || []
        for (var i = 0; i < children.length; ++i) {
            var found = named(children[i], name)
            if (found) return found
        }
        return object.contentItem ? named(object.contentItem, name) : null
    }
    function pressBadge(panel) {
        var badge = named(panel, "dock-doctor-badge")
        if (!badge) throw new Error("Dock Doctor badge not found")
        badge.triggerPress(Qt.LeftButton)
    }
    function live(panel) {
        var view = named(panel, "dock-doctor-view")
        return panel && panel.opened && view && view.connected && !view.demo
            && view.snapshot.ready && view.snapshot.devices.length > 0 ? view : null
    }
    Component.onCompleted: {
        var component = Qt.createComponent("file://" + Quickshell.env("DOCK_PLUGIN_DIR") + "/Panel.qml", Component.Asynchronous)
        function ready() {
            if (component.status === Component.Ready) root.pluginComponent = component
            else if (component.status === Component.Error) throw new Error(component.errorString())
        }
        if (component.status === Component.Loading) component.statusChanged.connect(ready)
        else ready()
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.ticks++
            if (root.phase === 0 && first.item && second.item) {
                root.pressBadge(first.item)
                root.pressBadge(second.item)
                root.phase = 1
            } else if (root.phase === 1 && root.live(first.item) && root.live(second.item)) {
                if (first.item.connection !== second.item.connection) throw new Error("Windows must share one observer connection")
                root.observedAt = root.live(second.item).snapshot.observedAt
                console.log("Both cold-loaded badge windows show live readings")
                root.pressBadge(first.item)
                root.pressBadge(second.item)
                if (first.item.opened || second.item.opened) throw new Error("Badge must close its window")
                root.phase = 2
            } else if (root.phase === 2 && second.item.connection.snapshot.observedAt !== root.observedAt) {
                root.pressBadge(first.item)
                root.pressBadge(second.item)
                root.phase = 3
            } else if (root.phase === 3 && root.live(first.item) && root.live(second.item)) {
                console.log("Both cold-loaded badge windows show fresh live readings after reopening")
                Qt.quit()
            }
            if (root.ticks >= 120) {
                console.error("Cold-loaded badge windows unavailable, phase:", root.phase)
                Qt.exit(1)
            }
        }
    }
}
