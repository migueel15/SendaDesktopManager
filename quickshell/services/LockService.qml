pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
    id: root
    property bool locked: false
    property bool preparing: false
    property string errorMessage: ""
    property string pendingPassword: ""
    readonly property bool authenticating: pam.active
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/senda/session-locked"

    function lock() {
        if (locked || preparing) return;
        preparing = true;
        errorMessage = "";
        prepare.running = true;
    }
    function authenticate(password) {
        if (!locked || pam.active || password.length === 0) return;
        errorMessage = "";
        pendingPassword = password;
        if (!pam.start()) { pendingPassword = ""; errorMessage = "No se pudo iniciar PAM"; }
    }
    function finish() {
        pendingPassword = "";
        locked = false;
        clearMarker.running = true;
    }
    Component.onCompleted: checkMarker.running = true
    IpcHandler {
        target: "lock"
        function lock() { root.lock(); }
        function isLocked(): bool { return root.locked || root.preparing; }
    }
    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) {
                if (root.pendingPassword.length > 0) {
                    const response = root.pendingPassword;
                    root.pendingPassword = "";
                    respond(response);
                } else {
                    abort();
                    root.errorMessage = "PAM solicita una respuesta adicional";
                }
            }
        }
        onCompleted: function(result) {
            root.pendingPassword = "";
            if (result === PamResult.Success) root.finish();
            else if (result === PamResult.Failed) root.errorMessage = "Contraseña incorrecta";
            else if (result === PamResult.MaxTries) root.errorMessage = "Demasiados intentos";
            else root.errorMessage = "No se pudo autenticar";
        }
    }
    Process {
        id: prepare
        command: ["sh", "-c", "mkdir -p -- \"$1\" && touch -- \"$2\" || echo \"No se pudo guardar el marcador de recuperación\" >&2; \"$3\" keyboard on", "senda-lock", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/senda", root.marker, SendaManager.binaryPath]
        stderr: StdioCollector { onStreamFinished: if (text) console.warn("LockService:", text) }
        onExited: function(code) {
            if (code !== 0) console.warn("LockService: no se pudo reactivar el teclado:", code);
            root.locked = true;
            root.preparing = false;
        }
    }
    Process { id: clearMarker; command: ["rm", "-f", "--", root.marker] }
    Process {
        id: checkMarker
        command: ["test", "-f", root.marker]
        onExited: function(code) { if (code === 0) root.lock(); }
    }
}
