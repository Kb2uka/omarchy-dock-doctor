import QtQuick
import QtQuick.Controls
import "Palette.js" as P

Menu {
    implicitWidth:220
    padding:4
    font.family:P.family
    font.pixelSize:12
    palette.window:P.surface
    palette.windowText:P.text
    palette.text:P.text
    palette.buttonText:P.text
    palette.highlight:P.raised
    palette.highlightedText:P.text
    palette.midlight:P.raised
    background:Rectangle { color:P.surface; border.color:P.border; radius:6 }
}
