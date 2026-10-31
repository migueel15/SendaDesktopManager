pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Asks on every screen, because a change may have left some of them black.
Variants {
    model: SendaDisplaySettings.confirming ? Quickshell.screens : []

    PanelWindow {
        id: dialog
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "senda-display-confirm"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }

        // Dark veil over the whole screen, fading in.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.65)
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            implicitWidth: Theme.scaled(460)
            implicitHeight: content.implicitHeight + 2 * Theme.spacing.xl
            color: Theme.colors.surface
            radius: Theme.rounding.normal

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacing.xl }
                spacing: Theme.spacing.lg
                Text {
                    Layout.fillWidth: true
                    text: "¿Mantener estos cambios?"
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(20)
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Se revertirán en " + SendaDisplaySettings.confirmLeft + " s."
                    color: Theme.colors.overlay
                    font.family: Theme.textFamily
                    font.pixelSize: Theme.scaled(15)
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.spacing.sm
                    SettingsButton { label: "Revertir"; onClicked: SendaDisplaySettings.revert() }
                    SettingsButton { label: "Mantener"; primary: true; onClicked: SendaDisplaySettings.keep() }
                }
            }
        }
    }
}
