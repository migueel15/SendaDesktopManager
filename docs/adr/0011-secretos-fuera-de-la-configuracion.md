# ADR 0011: Secretos fuera de la configuración

- Estado: aceptada
- Fecha: 2026-10-31

## Contexto

`~/.config/senda` debe poder compartirse entre equipos, pero `config` guardaba `DORLAB_API_KEY` y `SENDA_GOOGLE_CLIENT_SECRET`.

## Decisión

Los dos valores se guardan en Secret Service. `SENDA_GOOGLE_CLIENT_ID` sigue siendo una preferencia: identifica el cliente, no autentica, y conviene que viaje con la configuración.

Sin keyring disponible, esos dos valores van a `$XDG_STATE_HOME/senda/secrets` con permisos `0600`, fuera de la carpeta compartida, y nunca a `config`. Pasan al keyring en cuanto vuelve a responder. Es una excepción acotada a la regla de no usar texto plano: el refresh token de Google, de larga duración, sigue solo en el keyring según el ADR 0005.

La migración ocurre al leer un secreto. Una clave sale de `config` solo después de confirmar su guardado, y su valor sustituye al almacenado porque es el último que escribió el usuario. Las variables de entorno mantienen la prioridad. `senda config secret` escribe secretos por stdin.

## Consecuencias

Compartir `config` no expone secretos. En un equipo nuevo hay que reconectar Calendar y volver a introducir los secretos, sin errores al arrancar. El archivo de respaldo no está cifrado. Leer un secreto puede esperar al desbloqueo del keyring.
