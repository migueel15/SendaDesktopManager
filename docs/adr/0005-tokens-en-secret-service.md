# ADR 0005: Tokens de Google en Secret Service

- Estado: aceptada
- Fecha: 2026-10-22

## Contexto

El almacenamiento JSON con permisos `0600` del ADR 0002 no cifra el token de renovación en disco. Senda necesita delegar su custodia a un almacén de secretos compatible con distintas sesiones Linux.

## Decisión

Sustituir la decisión 4 del ADR 0002: usar Secret Service mediante `secret-tool` de libsecret. El proveedor (GNOME Keyring o KWallet compatible) custodia y cifra el secreto; el usuario debe configurar un almacén protegido con contraseña. Senda no guarda una clave propia ni usa texto plano como alternativa. El token se transmite por stdin y los diagnósticos externos no se muestran para evitar filtraciones.

La ruta de estado anterior identifica la entrada mediante un hash. Al primer acceso se migra el JSON existente, validando sus permisos, y se elimina solo después de guardar en el keyring. Si ya hay una entrada, prevalece sobre el JSON heredado. Logout elimina la entrada y el archivo heredado antes de solicitar la revocación remota.

## Consecuencias

Calendar requiere libsecret y un proveedor Secret Service disponible y desbloqueado. Senda no impone ni comprueba la contraseña o el algoritmo de cifrado del proveedor. No se instala ni modifica la configuración de un keyring automáticamente. Un fallo impide conectar o consultar Calendar, sin afectar al resto del escritorio. Cambiar la ruta de estado requiere volver a conectar. La migración no elimina copias de seguridad ni garantiza borrado físico del archivo antiguo.
