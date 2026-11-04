import QtQuick

import qs.common

// Single-line text input in the Zenda style. Set secret to hide the text.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool secret: false

    signal accepted()
    // Up or Down was pressed while typing: -1 or 1.
    signal arrowPressed(int step)
    signal committed()
    property bool dirty: false
    property string originalText: ""

    function commit() {
        if (!root.dirty) return;
        root.dirty = false;
        if (input.text === root.originalText) return;
        root.originalText = input.text;
        root.committed();
    }

    function focusInput() { input.forceActiveFocus(); }

    implicitHeight: input.implicitHeight + Theme.spacing.lg
    radius: Theme.rounding.control
    color: input.activeFocus ? Theme.colors.surfaceVariant : Theme.colors.surface
    Behavior on color { ColorAnimation { duration: Theme.motion.normal } }

    // Focus underline that grows from the centre.
    Rectangle {
        anchors { bottom: parent.bottom; bottomMargin: 2; horizontalCenter: parent.horizontalCenter }
        height: 2
        radius: 1
        color: Theme.colors.primary
        width: input.activeFocus ? parent.width - 2 * Theme.rounding.control : 0
        Behavior on width { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutQuint } }
    }

    TextInput {
        id: input
        Keys.onUpPressed: root.arrowPressed(-1)
        Keys.onDownPressed: root.arrowPressed(1)
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing.md
        anchors.rightMargin: Theme.spacing.md
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        color: Theme.colors.text
        font.family: Theme.font.base.family
        font.pixelSize: Theme.scaled(12)
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        onTextEdited: root.dirty = true
        // Enter confirms and ends editing; handlers of accepted() may still
        // move the focus elsewhere, such as to the next field.
        onAccepted: {
            input.focus = false;
            root.commit();
            root.accepted();
        }
        onActiveFocusChanged: {
            if (activeFocus) root.originalText = input.text;
            else root.commit();
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacing.md
        visible: input.text === ""
        text: root.placeholder
        color: Theme.colors.overlay
        font.family: Theme.font.base.family
        font.pixelSize: Theme.scaled(12)
    }
}
