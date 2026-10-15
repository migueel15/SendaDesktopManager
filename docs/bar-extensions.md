# Extensiones de la barra

Las extensiones pueden declararse incompatibles entre sí asignándoles el mismo `conflictGroup`:

```qml
Item {
    id: root
    property bool expanded: false

    BarComponents.BarExtension {
        conflictGroup: "tray-popups"
        expanded: root.expanded
        onCloseRequested: root.expanded = false
    }
}
```

Al abrir una extensión, `BarExtensionManager` pide el cierre de las otras instancias abiertas del mismo grupo mediante `closeRequested`. El componente que la contiene debe conectar esa señal con su estado de apertura. El grupo vacío, que es el valor predeterminado, no coordina ni cierra otras extensiones. De este modo, los grupos independientes pueden permanecer abiertos simultáneamente.

Actualmente, la extensión del widget de música y la del System Tray comparten el grupo `tray-popups`.
