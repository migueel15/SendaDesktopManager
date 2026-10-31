pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.common

// Dropdown in the Senda style for lists too long for SettingsSegments.
Rectangle {
    id: root
    property var options: []
    property string value: ""
    property string placeholder: "Sin definir"
    signal chosen(string value)

    implicitWidth: Theme.scaled(220)
    implicitHeight: label.implicitHeight + 2 * Theme.spacing.sm
    color: area.containsMouse && root.enabled ? Theme.colors.surfaceVariant : Theme.colors.base
    border { width: 1; color: popup.visible ? Theme.colors.primary : Theme.colors.border }
    radius: Theme.rounding.normal
    opacity: enabled ? 1 : 0.4
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: root.value || root.placeholder
    Keys.onSpacePressed: popup.open()
    Keys.onReturnPressed: popup.open()

    Text {
        id: label
        anchors { left: parent.left; right: chevron.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.spacing.sm; rightMargin: Theme.spacing.xs }
        text: root.value || root.placeholder
        color: root.value ? Theme.colors.text : Theme.colors.overlay
        font: Theme.font.body
        elide: Text.ElideRight
    }
    Text {
        id: chevron
        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.spacing.sm }
        text: ""
        color: Theme.colors.overlay
        font.family: Theme.iconFamily
        font.pixelSize: Theme.scaled(10)
        rotation: popup.visible ? 180 : 0
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible ? popup.close() : popup.open()
    }

    Controls.Popup {
        id: popup
        y: root.height + Theme.spacing.xs
        width: root.width
        height: Math.min(list.contentHeight, Theme.scaled(240)) + 2 * padding
        padding: Theme.spacing.xs
        focus: true
        onOpened: list.positionViewAtIndex(Math.max(0, root.options.indexOf(root.value)), ListView.Center)
        background: Rectangle {
            color: Theme.colors.surface
            border { width: 1; color: Theme.colors.border }
            radius: Theme.rounding.normal
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: option
                required property string modelData
                readonly property bool current: modelData === root.value
                width: ListView.view.width
                height: optionText.implicitHeight + 2 * Theme.spacing.xs
                radius: Theme.rounding.small
                color: current ? Theme.colors.primary : optionArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"
                Text {
                    id: optionText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacing.sm }
                    text: option.modelData
                    color: option.current ? Theme.colors.base : Theme.colors.text
                    font: Theme.font.body
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        popup.close();
                        root.chosen(option.modelData);
                    }
                }
            }
        }
    }
}
