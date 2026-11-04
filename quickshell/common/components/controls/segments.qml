pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common

// Style B segmented choice: equal-width options on a pill track, with a
// highlight that slides with a spring from the previous option to the new one.
// Give it options ([{label, value}]) and value, and handle chosen(value).
Rectangle {
    id: root
    property var options: []
    property string value: ""
    signal chosen(string value)

    readonly property int count: Math.max(1, options.length)
    readonly property int currentIndex: options.findIndex(option => option.value === root.value)
    readonly property real inset: Theme.spacing.xs
    readonly property real segmentWidth: (width - 2 * inset) / count
    // Widest label sets every segment's width, so they all match.
    property real widestLabel: 0

    implicitWidth: count * (widestLabel + 2 * Theme.spacing.md) + 2 * inset
    implicitHeight: Theme.scaled(34)
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: Theme.colors.surface
    radius: Theme.rounding.full
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: highlight
        visible: root.currentIndex >= 0
        x: root.inset + Math.max(0, root.currentIndex) * root.segmentWidth
        y: root.inset
        width: root.segmentWidth
        height: root.height - 2 * root.inset
        radius: Theme.rounding.full
        color: Theme.colors.primary
        Behavior on x { SpringAnimation { spring: Theme.motion.spring; damping: Theme.motion.damping } }
    }

    Row {
        x: root.inset
        y: root.inset
        Repeater {
            model: root.options
            delegate: Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool selected: index === root.currentIndex
                width: root.segmentWidth
                height: root.height - 2 * root.inset
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: selected

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rounding.full
                    color: Theme.colors.surfaceVariant
                    opacity: hover.hovered && !segment.selected && root.enabled ? 0.6 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Theme.spacing.sm)
                    elide: Text.ElideRight
                    text: segment.modelData.label
                    color: segment.selected ? Theme.colors.base : Theme.colors.textMuted
                    font.family: Theme.textFamily
                    font.pixelSize: Theme.scaled(12)
                    font.weight: Font.Bold
                    Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
                    Component.onCompleted: root.widestLabel = Math.max(root.widestLabel, implicitWidth)
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { enabled: root.enabled; onTapped: root.chosen(segment.modelData.value) }
            }
        }
    }
}
