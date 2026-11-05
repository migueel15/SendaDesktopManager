import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.common

RowLayout {
    id: root
    property real value: 100
    property real from: 80
    property real to: 150
    property real stepSize: 10
    property string suffix: " %"
    // Hides the value label when the caller shows it elsewhere.
    property bool showValue: true
    signal committed(real value)
    // Fires on every change made by the user, for live controls like volume.
    signal moved(real value)
    // Reconcile with persisted state after a save, including a failed write.
    onValueChanged: slider.value = root.value
    onEnabledChanged: if (enabled) slider.value = root.value
    Component.onCompleted: slider.value = root.value
    spacing: Theme.spacing.sm
    Controls.Slider {
        id: slider
        Layout.fillWidth: true
        Layout.preferredWidth: 120
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Controls.Slider.SnapAlways
        onPressedChanged: if (!pressed) root.committed(value)
        onMoved: root.moved(value)
        Keys.onReleased: event => {
            if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End].includes(event.key))
                root.committed(value);
        }
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: Theme.scaled(12)
            radius: Theme.rounding.full
            color: Theme.colors.surfaceVariant
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: Theme.colors.primary }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            // Thin vertical marker that stretches while dragged.
            implicitWidth: Theme.scaled(4)
            implicitHeight: slider.pressed ? Theme.scaled(26) : Theme.scaled(20)
            radius: Theme.rounding.full
            color: slider.visualFocus ? Theme.colors.secondary : Theme.colors.white
            Behavior on implicitHeight { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
        }
    }
    Text { visible: root.showValue; text: `${Math.round(slider.value)}${root.suffix}`; color: Theme.colors.text; font: Theme.font.body }
}
