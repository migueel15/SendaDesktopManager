# ADR 0002: Autenticación con Google Calendar

## Estado

Aceptada

## Contexto

El dashboard de Senda necesita mostrar los eventos del calendario de Google del usuario. Para eso hace falta autorizar la aplicación con OAuth 2.0 y guardar un refresh token que permita renovar el acceso sin pedir inicio de sesión cada vez.

Senda es un programa de escritorio sin servidor propio. El cliente OAuth es de tipo "Aplicación de escritorio" y su secreto no puede considerarse confidencial en el sentido estricto, pero tampoco debe quedar en el repositorio ni en los logs. El refresh token da acceso continuo a la cuenta del usuario y es el dato más sensible que Senda guardaría.

Quickshell es un proceso de interfaz que no debería manejar credenciales. El núcleo Go (`core/`) ya gestiona la configuración y los comandos de usuario.

## Decisión

1. **Flujo.** Autorización con Authorization Code y PKCE, con redirección a un puerto libre en `127.0.0.1`. `senda calendar login` abre el navegador, recibe el código en ese puerto y lo intercambia por tokens. No se usa el flujo de dispositivo.

2. **Ámbitos.** Solo lectura: `calendar.events.readonly` y `calendar.calendarlist.readonly`. Se descarta `calendar.readonly` porque da acceso a calendarios compartidos y a su configuración, y la funcionalidad no lo necesita.

3. **Dónde vive el acceso.** Todo el acceso a la API de Google y la renovación de tokens están en el núcleo Go. Quickshell solo ejecuta `senda calendar events` y lee JSON de la salida estándar. Quickshell nunca recibe tokens ni secretos.

4. **Almacenamiento del token.** `$XDG_STATE_HOME/senda/google-calendar.json` (por defecto `~/.local/state/senda/google-calendar.json`), con permisos `0600` y directorio con permisos `0700`. Contiene el refresh token y los metadatos necesarios. Se escribe de forma atómica. No se guarda en el archivo de configuración porque es un estado de sesión, no una preferencia del usuario.

5. **Secreto del cliente.** Se guarda en `$XDG_CONFIG_HOME/senda/config` con permisos `0600`, bajo una clave propia. Nunca se escribe en logs, en mensajes de error ni en el repositorio. Una variable de entorno con el mismo nombre tiene prioridad, como en el resto de la configuración.

6. **Cierre de sesión.** `senda calendar logout` revoca el token en Google y borra el archivo de estado.

## Consecuencias

- Sin un cliente OAuth propio, el usuario no puede conectar Google Calendar. La documentación debe explicar cómo crearlo.
- Si la aplicación de Google Cloud queda en modo "Testing", el refresh token caduca a los 7 días. La documentación debe advertirlo y recomendar publicar la aplicación.
- El archivo de estado y el de configuración deben tener permisos restringidos. Si los permisos no son los esperados, Senda debe avisar y negarse a usar el archivo.
- Quickshell depende del binario `senda` para los datos del calendario. Si el binario no está disponible, la tarjeta muestra un aviso.
- Añadir otros proveedores de calendario requerirá un nuevo ADR, porque el modelo de tokens y ámbitos es específico de Google.
