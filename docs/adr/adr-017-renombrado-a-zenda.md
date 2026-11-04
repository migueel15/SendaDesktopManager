# ADR 017: Renombrado de Senda a Zenda

- Estado: aceptada
- Fecha: 2026-11-04

## Contexto

El proyecto cambia su marca de Senda a Zenda. El nombre está en el binario, el servicio de usuario, las variables `SENDA_*`, los directorios del usuario, la carpeta que se genera en Hyprland, la entrada del keyring y el repositorio. Quien ya tiene Senda instalada no debe perder su configuración.

## Decisión

Todo pasa a `zenda`/`Zenda`/`ZENDA_*`, incluidos el módulo Go `github.com/migueel15/Zenda/core`, los tipos QML y el repositorio `migueel15/Zenda`. La web se sirve en `zenda.dorlab.net`.

La migración la hace el propio binario (`internal/legacy`) al arrancar cualquier comando, y es idempotente:

- Mueve `senda` a `zenda` en `$XDG_CONFIG_HOME`, `$XDG_DATA_HOME` (salvo con `ZENDA_HOME`), `$XDG_STATE_HOME` y `$XDG_CACHE_HOME`. Si el destino ya existe, no toca nada.
- Renombra las claves `SENDA_*` a `ZENDA_*` en `config` y en `secrets`. Una clave `ZENDA_*` ya presente gana.
- Acepta las variables de entorno `SENDA_*` como alias temporal: exporta la `ZENDA_*` correspondiente si no está definida.
- `zenda setup` elimina `senda.service` antes de instalar `zenda.service`.
- `zenda hyprland` retira la carpeta generada `hypr/senda` y sustituye su línea gestionada en `hyprland.lua`.
- Los secretos guardados en el keyring con el nombre antiguo se copian a la entrada nueva al leerlos.
- `install.sh` borra el binario `senda` antiguo.

## Consecuencias

El alias `SENDA_*` y el código de `internal/legacy` se pueden retirar en una versión futura. Los binarios antiguos buscan los artefactos `senda-*` en las releases, que ya no se publican: quien tenga Senda debe volver a ejecutar `install.sh`. GitHub redirige el repositorio antiguo, pero no hay que depender de ello a largo plazo.
