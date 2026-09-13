import QtQuick
import "Palette.js" as P

Text {
    color: P.text
    font.family: P.family
    font.pixelSize: 12
    textFormat: Text.PlainText
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
