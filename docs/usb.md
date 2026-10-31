# Montaje automático de USB

Senda monta sin `sudo` los sistemas de archivos de las unidades USB extraíbles al conectarlas, mediante udisks2 (`udisks2` se instala con `senda setup`). La shell mantiene el proceso oculto `senda usb watch`.

- Cada partición se monta en `/run/media/<usuario>/<etiqueta>`, donde la ven los exploradores de archivos, y llega una notificación con el nombre y la ruta.
- Al desconectar la unidad, udisks retira el montaje y su carpeta.
- Si el montaje falla, una notificación indica el error.
- Los dispositivos ya conectados al arrancar la sesión no se montan.
- Las unidades cifradas y los discos USB que el sistema no marca como extraíbles no se montan.

## Otros automontadores

Si está en ejecución `udiskie`, `devmon` o `udevil`, Senda no monta nada y deja el trabajo a ese programa. Si otro programa monta primero el dispositivo, Senda tampoco notifica.
