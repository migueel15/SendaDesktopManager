# Memoria y carga de interfaces

## Criterio de diseño

Las vistas ocultas que pueden reconstruirse a partir del estado de sus servicios se crean bajo demanda y se descargan al cerrar. El cierre conserva la vista hasta que termine su animación. La política está recogida en [ADR 013](adr/adr-013-lazy-interface-lifecycle.md).

El estado duradero y las operaciones viven en los servicios: cerrar una vista no debe cancelar una descarga, una escritura de configuración, un emparejamiento, una tarea activa ni un dictado. Los puntos de entrada IPC también deben existir antes de abrir su interfaz por primera vez.

## Implementación

- Los cinco paneles de `OverlayLayer` usan `PanelLoader`, solo en el monitor solicitado. El contenedor intermedio conserva las dimensiones del panel: el `Loader` ocupa la pantalla, pero no redimensiona directamente el `SendaPanel`.
- Ajustes carga su contenido al abrir. Cada página tiene su propio `Loader`; normalmente solo existe la seleccionada. Buscar carga temporalmente todas las páginas para consultar sus filas reales. Vaciar la búsqueda descarga las no seleccionadas que no tengan un borrador.
- La sección seleccionada se conserva como un entero en `SendaSettings`. Las consultas específicas de una página se hacen al cargarla, en vez de consultar todos los subsistemas al abrir Ajustes.
- Los selectores de temas y fondos, los popups de música, Discord y bandeja, los OSD, la autenticación polkit y el editor de capturas usan carga bajo demanda. El agente polkit, las conexiones de volumen y el receptor IPC de brillo permanecen disponibles.
- Las ventanas de notificaciones existen mientras hay popups. La transición `populate` cubre la primera aparición de una ventana recién construida.
- Los exploradores de archivos para fondos solo se crean al entrar en la exploración. Los menús de bandeja conservan su controlador de apertura, pero descargan su contenido y dejan de solicitar el menú D-Bus cuando están ocultos.
- Las sombras de `BarExtension` descargan su efecto al plegarse. La extensión empieza con altura cero y difiere su apertura hasta terminar la construcción del árbol.
- Las carátulas y avatares limitan la resolución de decodificación al tamaño mostrado y a la escala de la pantalla; sus imágenes no usan la caché global. Las miniaturas de edición también tienen un límite explícito.

## Borradores y recursos residentes

`common/components/lazy/lifetime.js` reconoce `dirty`, `editingTitle` y `retainWhenHidden` en el árbol visual. Una vista con entrada pendiente permanece cargada, aunque esté oculta. Los formularios de creación de tareas, credenciales OAuth, inicio, localidad, edición de temas e importación de fondos declaran sus casos particulares.

Una vista nueva con entrada sin guardar debe exponer `retainWhenHidden` o un estado reconocido por ese helper. No debe marcarse como reconstruible si perdería texto, selección necesaria para una operación o un resultado pendiente. Conservar la vista completa mientras existe un borrador es una excepción deliberada a la descarga.

Los singletons QML, la barra y los fondos visibles, los receptores IPC, el bloqueo Wayland y los procesos que proporcionan funciones de fondo tienen un ciclo de vida distinto al de las vistas. La preferencia de precarga del dictado sigue controlando si su motor queda residente. Cerrar un panel no modifica esa preferencia.

## Validación pendiente en sesión

La implementación tiene comprobación estática de QML; el comportamiento gráfico y el ahorro real requieren validación del usuario sobre la versión modificada:

1. Antes de abrir ningún panel, probar los comandos del lanzador, ajustes, temas, fondos, notificaciones, brillo, captura y dictado.
2. Abrir, cerrar y reabrir los paneles en cada monitor, incluidos cambios rápidos entre paneles y de monitor. Comprobar tamaño, foco y animaciones completas.
3. Recorrer las doce páginas de Ajustes. Buscar una fila de una página no visitada, abrir el resultado y vaciar la búsqueda. Abrir Actualización desde su aviso con Ajustes cerrado.
4. Dejar texto sin guardar en tareas, OAuth e inicio; cambiar de sección o cerrar y reabrir la vista. Comprobar que sigue disponible y que cancelar o guardar permite descargar la vista.
5. Probar menús y submenús de bandeja, arrastre para anclar, popups de música y Discord, selectores, importaciones, editor de capturas y diálogos cuando se necesiten.
6. Medir PSS/RSS y CPU de `qs` con los mismos monitores, fondos y actividad, antes de abrir interfaces y después de abrirlas y cerrarlas. Repetir recorridos para distinguir cachés del crecimiento sostenido.

La destrucción de objetos QML no garantiza que el asignador o el driver devuelvan inmediatamente todas las páginas al sistema. No debe anunciarse un porcentaje de ahorro a partir de contar `Loader` o de comparar condiciones distintas.
