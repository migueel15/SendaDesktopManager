pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

PanelWindow {
    id: dialog
    property bool viewReady: false
    readonly property var request: Bluetooth.pairingPrompt
    readonly property string kind: dialog.request?.kind ?? ""
    readonly property bool needsInput: kind === "pin" || kind === "passkey"
    readonly property bool validInput: kind === "passkey" ? /^[0-9]{1,6}$/.test(codeInput.text) : codeInput.text.length > 0 && codeInput.text.length <= 16
    screen: Quickshell.screens.find(screen => screen.name === OverlayService.currentScreen) ?? Quickshell.screens[0]
    visible: dialog.request !== null
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "senda-bluetooth-pair"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    function prepareRequest() {
        if (!dialog.viewReady) return;
        codeInput.text = "";
        if (dialog.needsInput) Qt.callLater(() => codeInput.focusInput());
    }

    onRequestChanged: prepareRequest()
    Component.onCompleted: {
        dialog.viewReady = true;
        prepareRequest();
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.65) }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(Theme.scaled(460), dialog.width)
        implicitHeight: content.implicitHeight + 2 * Theme.spacing.xl
        color: Theme.colors.surface
        radius: Theme.rounding.normal

        ColumnLayout {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.spacing.xl }
            spacing: Theme.spacing.lg

            Text {
                Layout.fillWidth: true
                text: "Emparejar dispositivo"
                color: Theme.colors.text
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(20)
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: Bluetooth.getDisplayName(Bluetooth.pairingDevice)
                textFormat: Text.PlainText
                color: Theme.colors.text
                font: Theme.font.body
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: dialog.kind === "confirm" ? "Comprueba que este código coincide con el del dispositivo."
                    : dialog.kind === "display" ? "Introduce este código en el dispositivo y confirma allí."
                    : dialog.needsInput ? "Introduce el código que solicita o muestra el dispositivo."
                    : dialog.kind === "service" ? "¿Permitir el servicio Bluetooth solicitado?"
                    : "¿Permitir el emparejamiento con este dispositivo?"
                color: Theme.colors.overlay
                font: Theme.font.body
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                visible: dialog.kind === "confirm" || dialog.kind === "display"
                text: dialog.request?.code ?? ""
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                color: Theme.colors.primary
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(30)
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                visible: dialog.kind === "service"
                text: dialog.request?.code ?? ""
                textFormat: Text.PlainText
                color: Theme.colors.overlay
                font: Theme.font.body
                wrapMode: Text.Wrap
            }
            SettingsField {
                id: codeInput
                Layout.fillWidth: true
                visible: dialog.needsInput
                placeholder: "PIN"
                onAccepted: if (dialog.validInput) Bluetooth.answerPairing(true, text)
                Keys.onEscapePressed: Bluetooth.answerPairing(false, "")
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.spacing.sm
                SettingsButton { label: "Cancelar"; onClicked: Bluetooth.answerPairing(false, "") }
                SettingsButton {
                    label: "Confirmar"
                    primary: true
                    visible: dialog.kind !== "display"
                    enabled: !dialog.needsInput || dialog.validInput
                    onClicked: Bluetooth.answerPairing(true, codeInput.text)
                }
            }
        }
    }
}
