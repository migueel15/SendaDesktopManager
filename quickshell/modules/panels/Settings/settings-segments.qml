pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root
    property var options: []
    property string value: ""
    signal chosen(string value)
    implicitWidth: segments.implicitWidth + Theme.spacing.xs * 2
    implicitHeight: segments.implicitHeight + Theme.spacing.xs * 2
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: Theme.colors.base
    radius: Theme.rounding.normal
    opacity: enabled ? 1 : 0.4
    RowLayout {
        id: segments
        anchors.fill: parent
        anchors.margins: Theme.spacing.xs
        spacing: Theme.spacing.xs
        Repeater {
            model: root.options
            delegate: SettingsButton {
                id: segment
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                label: segment.modelData.label
                primary: root.value === segment.modelData.value
                onClicked: root.chosen(segment.modelData.value)
            }
        }
    }
}
