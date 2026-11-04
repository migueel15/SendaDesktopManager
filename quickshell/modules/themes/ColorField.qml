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
        radius: Theme.rounding.control
        color: input.activeFocus ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: root.valid ? 0 : 1
        border.color: Theme.colors.error
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.md
            anchors.rightMargin: Theme.spacing.md
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
        radius: width / 2
        color: root.valid ? root.text : Theme.colors.surface
        border.width: root.valid ? 0 : 1
        border.color: Theme.colors.error
        Text {
            anchors.centerIn: parent
            visible: !root.valid
            text: "!"
            color: Theme.colors.error
            font: Theme.font.body
        }
    }
}
