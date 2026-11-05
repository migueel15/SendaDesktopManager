import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.components
import qs.common.components.barextension
import qs.services

Scope {
    id: root

    LazyLoader {
        // Keep the dock loaded until its close animation ends, even when the
        // resident session is already back in standby.
        active: ZendaStt.dockVisible

        PanelWindow {
            property bool entered: false
            readonly property bool listening: ZendaStt.phase === "listening"
            // Bars stay while the dictation finishes; only loading and errors show text.
            readonly property bool showBars: ZendaStt.phase !== "preparing"
                && ZendaStt.phase !== "starting" && ZendaStt.phase !== "error"
            readonly property bool expanded: listening && ZendaStt.transcript !== ""
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

            WlrLayershell.namespace: "zenda-stt-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // The dock grows out of the bottom screen frame, like a drop.
            readonly property int cornerSize: extension.cornerRadius
            readonly property int shadowSpace: 20

            anchors.bottom: true
            exclusiveZone: 0

            // Keep the layer surface stable while only the pill changes size.
            implicitWidth: Math.min(screen.width, maximumWidth + cornerSize * 2 + shadowSpace * 2)
            implicitHeight: maximumHeight + shadowSpace
            color: "transparent"
            mask: Region { item: extension }

            // The dock is a BarExtension growing out of the bottom frame, so it
            // shares its shape, joins and shadow with every bar extension.
            BarExtension {
                id: extension
                edge: "bottom"
                x: content.x - rootWindow.cornerSize
                width: content.width + 2 * rootWindow.cornerSize
                y: rootWindow.height - height
                expanded: rootWindow.entered && !ZendaStt.dockClosing
                expandedHeight: content.animatedHeight
                // The pill animates its own size, so the shape follows it.
                resizeDuration: 0
                contentFadeDistance: 0
                autoHideOnPointerExit: false
            }

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

                width: Math.round(animatedWidth)
                height: Math.round(animatedHeight)
                x: Math.round((rootWindow.width - width) / 2)
                // Rides on the extension, which unfolds out of the frame.
                y: rootWindow.height - extension.height
                clip: true
                color: "transparent"
                opacity: rootWindow.entered && !ZendaStt.dockClosing ? 1 : 0

                Behavior on animatedWidth {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }
                Behavior on animatedHeight {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.motion.slow; easing.type: Theme.motion.easing }
                }

                Component.onCompleted: Qt.callLater(() => rootWindow.entered = true)

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
                                id: barScale
                                origin.x: animatedBar.width / 2
                                origin.y: animatedBar.height / 2
                                yScale: Theme.spacing.sm / Theme.spacing.xl

                                Behavior on yScale {
                                    NumberAnimation { duration: Theme.motion.normal; easing.type: Theme.motion.easing }
                                }
                            }

                            Timer {
                                readonly property real restingScale: Theme.spacing.sm / Theme.spacing.xl
                                readonly property real maximumScale: animatedBar.index === 2 ? 1
                                    : (animatedBar.index === 1 || animatedBar.index === 3 ? 0.8 : 0.6)
                                running: rootWindow.listening && ZendaStt.audioActive && rootWindow.visible && !ZendaStt.dockClosing
                                repeat: true
                                triggeredOnStart: true
                                interval: Theme.motion.normal
                                onTriggered: {
                                    barScale.yScale = restingScale + (maximumScale - restingScale) * (0.3 + Math.random() * 0.7);
                                    interval = Theme.motion.fast + Math.round(Math.random() * Theme.motion.normal);
                                }
                                onRunningChanged: if (!running) barScale.yScale = restingScale
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
                    text: ZendaStt.phase === "preparing" ? "Preparando el modelo…"
                        : ZendaStt.phase === "starting" ? "Cargando el modelo…"
                        : ZendaStt.phase === "stopping" || ZendaStt.phase === "delivering" ? "Procesando…"
                        : ZendaStt.phase === "error" ? ZendaStt.errorMessage : "Dictado"
                    color: ZendaStt.phase === "error" ? Theme.colors.error : Theme.colors.text
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
                        // The stable prefix in the usual color; the words the end of the
                        // dictation may still revise, dimmed.
                        readonly property string stable: ZendaStt.transcript.startsWith(ZendaStt.stableTranscript)
                            ? ZendaStt.stableTranscript : ""
                        readonly property string tentative: ZendaStt.transcript.slice(transcriptText.stable.length)
                        function escaped(value) {
                            return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                        }
                        text: transcriptText.escaped(transcriptText.stable) + (transcriptText.tentative === "" ? ""
                            : "<font color=\"" + Theme.colors.overlay + "\">" + transcriptText.escaped(transcriptText.tentative) + "</font>")
                        color: Theme.colors.textMuted
                        font: Theme.font.body
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        onTextChanged: Qt.callLater(transcriptView.followTranscript)
                    }
                }
            }

            id: rootWindow
        }
    }
}
