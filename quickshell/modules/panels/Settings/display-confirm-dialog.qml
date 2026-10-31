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
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: Theme.scaled(340)
            implicitHeight: content.implicitHeight + 2 * Theme.spacing.lg
            color: Theme.colors.surface
            border { width: 1; color: Theme.colors.warning }
            radius: Theme.rounding.normal

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacing.lg }
                spacing: Theme.spacing.md
                Text {
                    Layout.fillWidth: true
                    text: "¿Mantener estos cambios?"
                    color: Theme.colors.text
                    font: Theme.font.body
                }
                Text {
                    Layout.fillWidth: true
                    text: "Se revertirán en " + SendaDisplaySettings.confirmLeft + " s."
                    color: Theme.colors.overlay
                    font: Theme.font.caption
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
