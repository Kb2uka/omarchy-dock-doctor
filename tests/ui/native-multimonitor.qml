import QtQuick
import Quickshell
import "dock" as Dock

ShellRoot {
    id: root
    Loader { id: first; sourceComponent: Dock.Panel {} }
    Loader { id: second; sourceComponent: Dock.Panel {} }
    property int ticks: 0
    property int phase: 0
    property int removedAt: 0
    property string previousObservation: ""
    function view(panel) {
        for (var i = 0; i < panel.data.length; ++i) {
            var window = panel.data[i]
            if (!window.contentItem) continue
            for (var j = 0; j < window.contentItem.children.length; ++j) {
                var child = window.contentItem.children[j]
                if (child.snapshot !== undefined && child.connected !== undefined) return child
            }
        }
        throw new Error("Plugin window not found")
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            root.ticks++
            var b = second.item ? root.view(second.item) : null
            var a = first.item ? root.view(first.item) : null
            if (root.phase === 0 && a && a.connected && b && b.connected && a.snapshot.ready && b.snapshot.ready) {
                if (!a.snapshot.devices.length || a.snapshot.devices.length !== b.snapshot.devices.length)
                    throw new Error("Both widgets must show the live inventory")
                console.log("Two widgets received live inventory:", b.snapshot.devices.length)
                root.previousObservation = b.snapshot.observedAt
                first.active = false
                root.phase = 1
            } else if (root.phase === 1 && b && b.connected && b.snapshot.observedAt !== root.previousObservation) {
                console.log("Remaining widget continues receiving observations")
                first.active = true
                root.phase = 2
            } else if (root.phase === 2 && a && a.connected && b && b.connected && a.snapshot.ready && b.snapshot.ready) {
                console.log("Recreated widget receives the same live inventory")
                first.active = false
                second.active = false
                root.removedAt = root.ticks
                root.phase = 3
            } else if (root.phase === 3 && root.ticks-root.removedAt >= 12) {
                if (Dock.LiveObserver.consumers !== 0 || Dock.LiveObserver.connection.alive)
                    throw new Error("Observer must stop when the last widget is removed")
                first.active = true
                second.active = true
                root.phase = 4
            } else if (root.phase === 4 && a && b && a.connected && b.connected && a.snapshot.ready && b.snapshot.ready) {
                console.log("All widgets removed and recreated successfully")
                Qt.quit()
            }
            if (root.ticks >= 80) {
                console.error("Multiple widgets did not receive live data:", a ? a.message : "removed", b ? b.message : "removed")
                Qt.exit(1)
            }
        }
    }
}
