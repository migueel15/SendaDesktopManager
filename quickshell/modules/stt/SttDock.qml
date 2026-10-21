import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

Scope {
    id: root

    LazyLoader {
        active: SendaStt.dockVisible && SendaStt.phase !== "standby"

        PanelWindow {
            property bool entered: false
            readonly property bool listening: SendaStt.phase === "listening"
            readonly property bool expanded: listening && SendaStt.transcript !== ""
            readonly property real maximumWidth: Math.min(screen.width - Theme.spacing.xl * 2, 560)

            WlrLayershell.namespace: "senda-stt-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.bottom: true
            margins.bottom: Theme.spacing.lg
            exclusiveZone: 0

            implicitWidth: content.width
            implicitHeight: content.height
            color: "transparent"
            mask: Region { item: content }

            Rectangle {
                id: content
                width: rootWindow.expanded ? rootWindow.maximumWidth
                    : Math.min(rootWindow.maximumWidth,
                        (rootWindow.listening ? listeningBars.implicitWidth : statusText.implicitWidth) + Theme.spacing.xl * 2)
                height: dockLayout.implicitHeight + Theme.spacing.md * 2
                radius: rootWindow.expanded ? Theme.rounding.large : Theme.rounding.full
                clip: true
                color: Theme.colors.background
                border.width: 1
                border.color: SendaStt.phase === "error" ? Theme.colors.error : Theme.colors.border
                opacity: rootWindow.entered && !SendaStt.dockClosing ? 1 : 0
                y: rootWindow.entered && !SendaStt.dockClosing ? 0 : height

                Behavior on width {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }
                Behavior on height {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }
                Behavior on radius {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Component.onCompleted: Qt.callLater(() => rootWindow.entered = true)
                Behavior on y {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: wheel => wheel.accepted = true
                }

                ColumnLayout {
                    id: dockLayout
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.md
                    spacing: Theme.spacing.xs

                    Item {
                        id: listeningBars
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: barRow.implicitWidth
                        implicitHeight: Theme.spacing.xl
                        visible: rootWindow.listening

                        Row {
                            id: barRow
                            anchors.centerIn: parent
                            height: Theme.spacing.xl
                            spacing: Theme.spacing.xs

                            Repeater {
                                model: 5

                                Rectangle {
                                    id: animatedBar
                                    required property int index
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Theme.spacing.xs
                                    height: Theme.spacing.sm
                                    radius: Theme.rounding.full
                                    color: Theme.colors.primary

                                    SequentialAnimation on height {
                                        running: rootWindow.listening && rootWindow.visible && !SendaStt.dockClosing
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: animatedBar.index * Theme.motion.fast }
                                        NumberAnimation {
                                            to: Theme.spacing.xl
                                            duration: Theme.motion.slow
                                            easing.type: Theme.motion.easing
                                        }
                                        NumberAnimation {
                                            to: Theme.spacing.sm
                                            duration: Theme.motion.slow
                                            easing.type: Theme.motion.easing
                                        }
                                        PauseAnimation { duration: (4 - animatedBar.index) * Theme.motion.fast }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        id: statusText
                        Layout.fillWidth: true
                        visible: !rootWindow.listening
                        text: SendaStt.phase === "preparing" ? "Preparando el modelo…"
                            : SendaStt.phase === "starting" ? "Cargando el modelo…"
                            : SendaStt.phase === "stopping" || SendaStt.phase === "delivering" ? "Procesando…"
                            : SendaStt.phase === "error" ? SendaStt.errorMessage : "Dictado"
                        color: SendaStt.phase === "error" ? Theme.colors.error : Theme.colors.text
                        font: Theme.font.body
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Flickable {
                        id: transcriptView
                        Layout.fillWidth: true
                        visible: rootWindow.expanded
                        implicitHeight: Math.min(transcriptText.implicitHeight, transcriptMetrics.height * 3)
                        contentWidth: width
                        contentHeight: transcriptText.implicitHeight
                        clip: true
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        function followTranscript() {
                            cancelFlick();
                            contentY = Math.max(0, contentHeight - height);
                        }

                        onContentHeightChanged: Qt.callLater(followTranscript)
                        onHeightChanged: Qt.callLater(followTranscript)

                        FontMetrics {
                            id: transcriptMetrics
                            font: Theme.font.body
                        }

                        Text {
                            id: transcriptText
                            width: transcriptView.width
                            text: SendaStt.transcript
                            color: Theme.colors.textMuted
                            font: Theme.font.body
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            onTextChanged: Qt.callLater(transcriptView.followTranscript)
                        }
                    }
                }
            }

            id: rootWindow
        }
    }
}
