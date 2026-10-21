import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

Scope {
    id: root

    LazyLoader {
        active: SendaStt.dockVisible

        PanelWindow {
            property bool entered: false

            WlrLayershell.namespace: "senda-stt-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.bottom: true
            margins.bottom: Theme.spacing.lg
            exclusiveZone: 0

            implicitWidth: Math.min(screen.width - Theme.spacing.xl * 2, 560)
            implicitHeight: dockLayout.implicitHeight + Theme.spacing.md * 2
            color: "transparent"
            mask: Region {}

            Rectangle {
                id: content
                anchors.fill: parent
                radius: Theme.rounding.large
                color: Theme.colors.background
                border.width: 1
                border.color: SendaStt.phase === "error" ? Theme.colors.error : Theme.colors.border
                opacity: rootWindow.entered && !SendaStt.dockClosing ? 1 : 0
                y: rootWindow.entered && !SendaStt.dockClosing ? 0 : height

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Component.onCompleted: Qt.callLater(() => rootWindow.entered = true)
                Behavior on y {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                ColumnLayout {
                    id: dockLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.md
                    spacing: Theme.spacing.xs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.sm

                        Rectangle {
                            implicitWidth: Theme.spacing.sm
                            implicitHeight: Theme.spacing.sm
                            radius: Theme.rounding.full
                            color: SendaStt.phase === "error" ? Theme.colors.error
                                : (SendaStt.phase === "listening" ? Theme.colors.primary : Theme.colors.overlay)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: SendaStt.phase === "starting" ? "Cargando el modelo…"
                                : SendaStt.phase === "listening" ? "Escuchando"
                                : SendaStt.phase === "stopping" || SendaStt.phase === "delivering" ? "Procesando…"
                                : SendaStt.phase === "error" ? SendaStt.errorMessage : "Dictado"
                            color: SendaStt.phase === "error" ? Theme.colors.error : Theme.colors.text
                            font: Theme.font.body
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: SendaStt.transcript !== ""
                        text: SendaStt.transcript
                        color: Theme.colors.textMuted
                        font: Theme.font.body
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideLeft
                    }
                }
            }

            id: rootWindow
        }
    }
}
