# ADR 0001: Distribución y ubicaciones

## Estado

Aceptada

## Contexto

Senda combina un binario Go (`core/`) con archivos de Quickshell (`quickshell/`) y un script Python del puente de Discord (`core/scripts/discord-bridge.py`). Los usuarios necesitan instalar y actualizar estos componentes sin compilar el código fuente, sin privilegios de administrador y sin tocar su configuración de escritorio.

Antes de este ADR había un archivo `.env` como fuente de valores del usuario y una ruta de desarrollo fija. Esto mezclaba secretos con datos del programa y dificultaba instalar fuera de un checkout.

## Decisión

1. **Distribución.** Las releases publican un binario precompilado para Linux amd64, un tarball con Quickshell y el puente de Discord, y un `checksums.txt` con SHA-256. El instalador y `senda update` descargan estos artefactos desde GitHub Releases y verifican la suma antes de instalar nada. Ninguna actualización compila código fuente.

2. **Archivos del programa.** Quickshell y el puente de Discord viven en el directorio de datos XDG (`$XDG_DATA_HOME/senda`, por defecto `~/.local/share/senda`). `senda update` reemplaza las entradas gestionadas (`quickshell/`, `scripts/`, `version`) en cada actualización y reinicia Quickshell después.

3. **Valores del usuario.** Los valores del usuario se guardan en un único archivo `KEY=VALUE` en el directorio de configuración XDG (`$XDG_CONFIG_HOME/senda/config`), con permisos `0600`. Sustituye al archivo `.env`, que ya no se lee. Una variable de entorno tiene prioridad sobre el archivo.

4. **`SENDA_HOME`.** Solo para desarrollo: apunta el directorio de datos a un checkout. Se lee del entorno, no del archivo de configuración, y deshabilita `senda update`.

5. **Alcance de la v1.** Solo Arch Linux con Hyprland.

6. **Privilegios y Hyprland.** El instalador y `senda setup` no requieren root y no editan la configuración de Hyprland. El arranque automático se resuelve con la unidad de usuario descrita en el ADR 0003.

7. **Sitio de instalación.** La landing se publica con GitHub Pages desde este repositorio, a partir de `site/`. Todavía no se ha decidido un dominio propio.

## Consecuencias

- Los usuarios no necesitan toolchain de Go ni de Python para usar Senda; el puente de Discord sí necesita `python3` en el sistema.
- Cada release debe incluir los tres artefactos con los nombres esperados. Si falta uno, la instalación o la actualización falla antes de tocar el disco.
- Una actualización siempre reinicia Quickshell, incluso si solo cambian los archivos de Quickshell.
- La separación entre datos y configuración permite reemplazar los archivos del programa sin perder los valores del usuario.
- `SENDA_HOME` está en el entorno del desarrollador, no en la configuración del usuario, por lo que un valor en el archivo no cambia la ruta de datos. Sin embargo, `senda update` sí lo consulta desde el archivo, lo que es una inconsistencia pendiente de corregir.
- La v1 deja fuera otras distribuciones y compositores. Ampliar el soporte requerirá revisar el instalador y `senda setup`.
- Hasta que se decida el dominio, la URL de instalación será la de GitHub Pages del repositorio y podrá cambiar.
