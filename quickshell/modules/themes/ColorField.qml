import QtQuick
import QtQuick.Layouts
import qs.common

RowLayout {
    id: root

    property string colorKey: ""
    property alias text: input.text
    readonly property bool valid: /^#[0-9A-Fa-f]{6}$/.test(text)
    signal edited(string value)

    spacing: Theme.spacing.sm
    implicitHeight: 36

    Text {
        Layout.fillWidth: true
        text: root.colorKey
        color: Theme.colors.text
        font: Theme.font.body
    }
    Rectangle {
        Layout.preferredWidth: 120
        Layout.preferredHeight: 32
        radius: Theme.rounding.small
        color: Theme.colors.background
        border.color: !root.valid ? Theme.colors.error
            : input.activeFocus ? Theme.colors.focus : Theme.colors.surfaceVariant
        TextInput {
            id: input
            anchors.fill: parent
            anchors.margins: Theme.spacing.sm
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            color: Theme.colors.text
            font: Theme.font.body
            onTextEdited: root.edited(text)
        }
    }
    Rectangle {
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Theme.rounding.small
        color: root.valid ? root.text : Theme.colors.surface
        border.color: root.valid ? Theme.colors.border : Theme.colors.error
        Text {
            anchors.centerIn: parent
            visible: !root.valid
            text: "!"
            color: Theme.colors.error
            font: Theme.font.body
        }
    }
}
