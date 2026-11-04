pragma Singleton

import QtQuick
import Quickshell

// Registry of the Zenda actions offered by the launcher. Every new interface
// declares its action here. An action has open(screenName), or query to fill
// the launcher search box instead.
Singleton {
    id: root

    readonly property var entries: [
        root.action("Ajustes", "Abrir los ajustes de Zenda", "󰒓", "settings configuracion preferencias",
            () => ZendaSettings.openSection("")),
        root.action("Selector de temas", "Cambiar el tema de Zenda", "󰏘", "theme tema colores picker",
            screenName => ZendaTheme.openPicker(screenName)),
        root.action("Duplicar tema activo", "Crear una copia editable del tema actual", "󰆏", "theme tema copia copiar duplicar duplicate",
            screenName => ZendaTheme.openDuplicate(screenName)),
        root.action("Selector de fondos", "Cambiar el fondo de pantalla", "󰸉", "wallpaper fondo imagen picker",
            screenName => WallpaperService.openPicker(screenName)),
        Object.assign(root.action("Emojis", "Buscar y copiar un emoji", "󰞅", "emoji emoticono :", null), { query: ":" }),
        Object.assign(root.action("Portapapeles", "Buscar y restaurar lo copiado", "󰅌", "clipboard historial copiado pegar #", null), { query: "#" }),
        root.action("Vaciar portapapeles", "Borrar el historial de lo copiado", "󰃢", "clipboard historial borrar limpiar",
            () => ZendaClipboard.clear()),
        root.action("Captura de pantalla", "Seleccionar una zona y capturarla", "󰹑", "screenshot captura",
            () => captureTimer.start()),
        root.action("Bloquear pantalla", "Bloquear la sesión", "󰌾", "lock bloquear",
            () => LockService.lock())
    ].concat(ZendaSettings.sections.map(section =>
        root.action("Ajustes: " + section.label, "Abrir esta sección de ajustes", section.icon,
            "settings ajustes configuracion " + section.keywords, () => ZendaSettings.openSection(section.label))))

    function action(name, detail, glyph, keywords, open) {
        return { kind: "action", name: name, genericName: detail, detail: detail, glyph: glyph, keywords: keywords.split(" "), open: open };
    }

    Timer {
        // Lets the launcher fold away before the screen is frozen.
        id: captureTimer
        interval: 250
        onTriggered: ScreenshotService.capture()
    }
}
