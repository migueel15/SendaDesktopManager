import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.common
import qs.common.components.barextension

// Polkit authentication shown as an extension of the top bar. When another
// agent already serves the session, registration fails and this stays hidden.
Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property bool open: flow !== null && !flow.isCompleted

    PolkitAgent {
        id: agent
        onIsRegisteredChanged: console.log("polkit: agent registered:", isRegistered)
    }

    PanelWindow {
        WlrLayershell.namespace: "senda-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors.top: true
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        implicitWidth: 460
        implicitHeight: extension.expandedHeight + extension.shadowSpace
        color: "transparent"
        visible: root.open || extension.height > 0.01

        BarExtension {
            id: extension
            width: parent.width
            y: -collapseLift
            expanded: root.open
            expandedHeight: content.implicitHeight + 32
            autoHideOnPointerExit: false

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: "Autenticación requerida"
                    color: Theme.colors.text
                    font: Theme.font.heading
                }

                Text {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    color: Theme.colors.text
                    font: Theme.font.body
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    text: "Acción: " + (root.flow?.actionId ?? "")
                    color: Theme.colors.text
                    opacity: 0.65
                    font: Theme.font.caption
                    elide: Text.ElideMiddle
                }

                // With several allowed accounts, a click moves to the next one.
                Text {
                    Layout.fillWidth: true
                    readonly property var identities: root.flow?.identities ?? []
                    text: "Usuario: " + (root.flow?.selectedIdentity?.displayName ?? "")
                        + (identities.length > 1 ? "  (pulsa para cambiar)" : "")
                    color: Theme.colors.text
                    font: Theme.font.caption

                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.identities.length > 1
                        onClicked: {
                            const list = parent.identities;
                            const index = list.indexOf(root.flow.selectedIdentity);
                            root.flow.selectedIdentity = list[(index + 1) % list.length];
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage
                        || (root.flow?.failed ? "Contraseña incorrecta" : "")
                    color: root.flow?.supplementaryIsError || root.flow?.failed
                        ? Theme.colors.error : Theme.colors.text
                    font: Theme.font.caption
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.rounding.normal
                        color: Theme.colors.surfaceVariant

                        TextInput {
                            id: password
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.colors.text
                            font: Theme.font.overlay
                            clip: true
                            focus: root.open
                            enabled: root.flow?.isResponseRequired ?? false
                            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            onEnabledChanged: if (enabled) forceActiveFocus()
                            onAccepted: submitButton.submit()
                            Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 84
                        Layout.fillHeight: true
                        radius: Theme.rounding.normal
                        color: Theme.colors.surfaceVariant

                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: Theme.colors.text
                            font: Theme.font.overlay
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.flow?.cancelAuthenticationRequest()
                        }
                    }

                    Rectangle {
                        id: submitButton
                        Layout.preferredWidth: 84
                        Layout.fillHeight: true
                        radius: Theme.rounding.normal
                        color: Theme.colors.primary

                        function submit() {
                            if (!password.enabled) return;
                            root.flow.submit(password.text);
                            password.text = "";
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Autorizar"
                            color: Theme.colors.background
                            font: Theme.font.overlay
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: submitButton.submit()
                        }
                    }
                }
            }
        }
    }
}
