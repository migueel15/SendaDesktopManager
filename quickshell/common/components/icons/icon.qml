import QtQuick

import qs.common

// Every interface icon: a Nerd Font glyph at the shared icon size, scaled with
// the interface text size from Settings. Set `text` to the glyph.
Text {
    color: Theme.colors.text
    font: Theme.font.icon
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
