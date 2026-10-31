# Historial del portapapeles

Senda guarda el texto copiado sin depender de `cliphist`. La shell inicia `senda clipboard watch`, que usa `wl-paste --watch` del paquete `wl-clipboard`. Solo hay un vigilante activo por sesión: uno nuevo releva al anterior.

## Uso

- En el lanzador, escribe `#` y parte del texto; Intro lo devuelve al portapapeles. La acción **Portapapeles** abre la misma búsqueda y **Vaciar portapapeles** borra el historial.
- `senda clipboard list [--json]` muestra las entradas, primero la más reciente.
- `senda clipboard restore <id>` devuelve una entrada al portapapeles.
- `senda clipboard clear` vacía el historial.

En Ajustes → Sistema se puede activar el historial, fijar el máximo de entradas (100 por defecto, hasta 1000) y vaciarlo. Los cambios se aplican a la siguiente copia. Desactivarlo deja de registrar, pero conserva lo guardado.

## Qué se guarda

- Solo texto UTF-8 de hasta 1 MiB. Las imágenes y otros datos binarios no se guardan.
- No se guarda lo que un gestor de contraseñas marca con `x-kde-passwordManagerHint`. Un gestor que no use esa marca no se puede distinguir.
- Copiar de nuevo un texto lo sube al principio en lugar de duplicarlo. Al superar el máximo se elimina la entrada más antigua.

El historial está en `$XDG_STATE_HOME/senda/clipboard-history.json`, sin cifrar y con permisos `0600`. Queda fuera de la carpeta compartida de configuración.
