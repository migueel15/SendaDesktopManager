import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.components
import qs.services

Scope {
    id: root

    LazyLoader {
        active: SendaStt.dockVisible && SendaStt.phase !== "standby"

        PanelWindow {
            property bool entered: false
            readonly property bool listening: SendaStt.phase === "listening"
            // Bars stay while the dictation finishes; only loading and errors show text.
            readonly property bool showBars: SendaStt.phase !== "preparing"
                && SendaStt.phase !== "starting" && SendaStt.phase !== "error"
            readonly property bool expanded: listening && SendaStt.transcript !== ""
            // The elapsed time appears under the bars once the dictation passes this mark.
            readonly property int timerDelay: 60
            property real listenStart: 0
            property int elapsed: 0
            readonly property bool showTimer: listening && elapsed >= timerDelay
            readonly property int timerHeight: Math.ceil(timerMetrics.height)
            readonly property int timerBlock: showTimer ? Theme.spacing.xs + timerHeight : 0
            readonly property int maximumWidth: Math.floor(Math.min(screen.width - Theme.spacing.xl * 2, 560))
            readonly property int maximumHeight: Math.ceil(Theme.spacing.md * 2
                + Theme.spacing.xl + Theme.spacing.xs + timerHeight + Theme.spacing.xs + transcriptMetrics.height * 3)

            function formatElapsed(seconds) {
                const minutes = Math.floor(seconds / 60);
                const rest = seconds % 60;
                return minutes + ":" + (rest < 10 ? "0" : "") + rest;
            }

            onListeningChanged: {
                if (listening) {
                    listenStart = Date.now();
                    elapsed = 0;
                }
            }
            Component.onCompleted: if (listening) listenStart = Date.now()

            Timer {
                interval: 1000
                repeat: true
                running: rootWindow.listening
                onTriggered: rootWindow.elapsed = Math.floor((Date.now() - rootWindow.listenStart) / 1000)
            }

            FontMetrics {
                id: timerMetrics
                font: Theme.font.caption
            }

            WlrLayershell.namespace: "senda-stt-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // The dock grows out of the bottom screen frame, like a drop.
            readonly property int cornerSize: Theme.barBorderRadius

            anchors.bottom: true
            exclusiveZone: 0

            // Keep the layer surface stable while only the pill changes size.
            implicitWidth: maximumWidth + cornerSize * 2
            implicitHeight: maximumHeight
            color: "transparent"
            mask: Region { item: content }

            Rectangle {
                id: content
                property real animatedWidth: rootWindow.expanded ? rootWindow.maximumWidth
                    : Math.min(rootWindow.maximumWidth,
                        (rootWindow.showBars
                            ? Math.max(listeningBars.width, rootWindow.showTimer ? Math.ceil(elapsedText.implicitWidth) : 0)
                            : statusText.implicitWidth) + Theme.spacing.xl * 2)
                property real animatedHeight: Theme.spacing.md * 2 + (rootWindow.showBars
                    ? Theme.spacing.xl + rootWindow.timerBlock
                        + (rootWindow.expanded ? Theme.spacing.xs + transcriptView.height : 0)
                    : Math.ceil(statusText.implicitHeight))
                property real slideOffset: rootWindow.entered && !SendaStt.dockClosing
                    ? 0 : rootWindow.maximumHeight

                width: Math.round(animatedWidth)
                height: Math.round(animatedHeight)
                x: Math.round((rootWindow.width - width) / 2)
                y: rootWindow.height - height + Math.round(slideOffset)
                radius: rootWindow.expanded ? Theme.rounding.large : Theme.rounding.full
                clip: true
                // Same color as the screen frame, without a border, so both read as one shape.
                color: Theme.colors.background
                opacity: rootWindow.entered && !SendaStt.dockClosing ? 1 : 0

                // Squares the bottom corners where the dock meets the frame.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.min(parent.radius, Math.floor(parent.height / 2))
                    color: parent.color
                }

                Behavior on animatedWidth {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }
                Behavior on animatedHeight {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }
                Behavior on radius {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Component.onCompleted: Qt.callLater(() => rootWindow.entered = true)
                Behavior on slideOffset {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: wheel => wheel.accepted = true
                }

                // Integer coordinates in the fixed window keep horizontal centering
                // independent of the animated pill's odd/even width.
                Item {
                    id: listeningBars
                    x: Math.round((rootWindow.width - width) / 2) - content.x
                    y: Theme.spacing.md
                    width: Theme.spacing.xs * 9
                    height: Theme.spacing.xl
                    visible: rootWindow.showBars

                    Repeater {
                        model: 5

                        Rectangle {
                            id: animatedBar
                            required property int index
                            x: index * Theme.spacing.xs * 2
                            width: Theme.spacing.xs
                            height: Theme.spacing.xl
                            radius: Theme.rounding.full
                            color: Theme.colors.primary

                            transform: Scale {
                                origin.x: animatedBar.width / 2
                                origin.y: animatedBar.height / 2
                                yScale: Theme.spacing.sm / Theme.spacing.xl

                                SequentialAnimation on yScale {
                                    running: rootWindow.showBars && rootWindow.visible && !SendaStt.dockClosing
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: animatedBar.index * Theme.motion.fast }
                                    NumberAnimation {
                                        to: 1
                                        duration: Theme.motion.slow
                                        easing.type: Theme.motion.easing
                                    }
                                    NumberAnimation {
                                        to: Theme.spacing.sm / Theme.spacing.xl
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
                    id: elapsedText
                    x: Math.round((rootWindow.width - width) / 2) - content.x
                    y: Theme.spacing.md + Theme.spacing.xl + Theme.spacing.xs
                    width: rootWindow.maximumWidth - Theme.spacing.md * 2
                    height: rootWindow.timerHeight
                    opacity: rootWindow.showTimer ? 1 : 0
                    visible: opacity > 0
                    text: rootWindow.formatElapsed(rootWindow.elapsed)
                    color: Theme.colors.textMuted
                    font: Theme.font.caption
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                    }
                }

                Text {
                    id: statusText
                    x: Theme.spacing.md
                    y: Theme.spacing.md
                    width: Math.max(0, content.width - Theme.spacing.md * 2)
                    visible: !rootWindow.showBars
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
                    x: Math.round((rootWindow.width - width) / 2) - content.x
                    y: Theme.spacing.md + Theme.spacing.xl + rootWindow.timerBlock + Theme.spacing.xs
                    width: rootWindow.maximumWidth - Theme.spacing.md * 2
                    height: Math.ceil(Math.min(transcriptText.implicitHeight, transcriptMetrics.height * 3))
                    opacity: rootWindow.expanded ? 1 : 0
                    visible: opacity > 0
                    interactive: rootWindow.expanded
                    contentWidth: width
                    contentHeight: transcriptText.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                    }
                    Behavior on y {
                        NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                    }

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

            // Concave corners that join the dock sides to the frame below.
            BarCorner {
                position: "bottom-right"
                cornerRadius: rootWindow.cornerSize
                shapeColor: Theme.colors.background
                x: content.x - width
                y: rootWindow.height - height + Math.round(content.slideOffset)
                opacity: content.opacity
            }

            BarCorner {
                position: "bottom-left"
                cornerRadius: rootWindow.cornerSize
                shapeColor: Theme.colors.background
                x: content.x + content.width
                y: rootWindow.height - height + Math.round(content.slideOffset)
                opacity: content.opacity
            }

            id: rootWindow
        }
    }
}
