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

Las extensiones reconstruibles se cargan bajo demanda y permanecen vivas hasta terminar su plegado. `BarExtension` difiere su primera apertura hasta que el árbol está construido y descarga el efecto de sombra al cerrarse. Los formularios con entrada pendiente deben declarar su retención; el criterio se describe en [Memoria y carga de interfaces](memory.md).
