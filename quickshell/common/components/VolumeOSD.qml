import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import Quickshell.Wayland
import qs.common
import qs.common.components.barextension

Scope {
    id: root

    // Bind the pipewire node so its volume will be tracked
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio

        function onVolumeChanged() {
            root.shouldShowOsd = true;
            hideTimer.restart();
        }
    }

    property bool shouldShowOsd: false

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.shouldShowOsd = false
    }

    PanelWindow {
        // Since the panel's screen is unset, it will be picked by the compositor
        // when the window is shown. Most compositors pick the current active monitor.
        WlrLayershell.namespace: "senda-volume-osd"

        // Center horizontally, just below the top bar.
        anchors.top: true
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.barSize
        exclusiveZone: 0

        implicitWidth: 250
        implicitHeight: 35 + extension.shadowSpace
        color: "transparent"
        visible: root.shouldShowOsd || extension.height > 0.01

        mask: Region {}

        BarExtension {
            id: extension
            width: parent.width
            y: -collapseLift
            expanded: root.shouldShowOsd
            expandedHeight: 35
            autoHideOnPointerExit: false

            RowLayout {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 10
                    rightMargin: 15
                }
                height: 35

                IconImage {
                    implicitSize: 18
                    source: Qt.resolvedUrl("../../assets/volume.svg")
                }

                Rectangle {
                    Layout.fillWidth: true

                    implicitHeight: 10
                    radius: Theme.rounding.full
                    color: Theme.colors.surfaceVariant

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }

                        color: Theme.colors.primary

                        implicitWidth: parent.width * (Pipewire.defaultAudioSink?.audio.volume ?? 0)
                        radius: parent.radius
                    }
                }
            }
        }
    }
}
