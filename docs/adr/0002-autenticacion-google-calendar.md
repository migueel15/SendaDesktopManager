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

5. **Cliente OAuth.** Las releases oficiales incluyen el ID y el secreto de un cliente de Senda. Se inyectan al compilar con `-ldflags -X` desde los secretos de GitHub Actions `SENDA_GOOGLE_CLIENT_ID` y `SENDA_GOOGLE_CLIENT_SECRET`, y `core/scripts/package-release.sh` se niega a publicar sin ellos. El secreto nunca aparece en el repositorio ni en los logs. Un usuario puede usar su propio cliente configurando `SENDA_GOOGLE_CLIENT_ID` y `SENDA_GOOGLE_CLIENT_SECRET` en `$XDG_CONFIG_HOME/senda/config`; en ese caso se usa el par configurado y nunca se mezcla con el incluido. Las compilaciones desde código fuente no incluyen cliente y exigen uno propio.

   Esta decisión sustituye a la versión inicial, que exigía a cada usuario su propio cliente. Se acepta que el secreto de una aplicación de escritorio no es confidencial: la protección del flujo la dan PKCE, la redirección a `127.0.0.1` y el consentimiento del usuario. El coste asumido es que cualquiera puede extraer el secreto del binario, y que rotarlo obliga a publicar una release nueva.

6. **Cierre de sesión.** `senda calendar logout` revoca el token en Google y borra el archivo de estado.

## Consecuencias

- Las compilaciones desde código fuente no tienen cliente OAuth. Quien compile Senda debe crear uno propio, o no podrá conectar Google Calendar.
- Google limita a 100 usuarios las aplicaciones no verificadas. Un cliente compartido por todas las releases consume ese límite entre todos los usuarios.
- Un abuso del cliente incluido afecta a la cuota de todos los usuarios. Rotar el secreto exige publicar una release nueva.
- Si la aplicación de Google Cloud queda en modo "Testing", el refresh token caduca a los 7 días. La documentación debe advertirlo y recomendar publicar la aplicación.
- El archivo de estado y el de configuración deben tener permisos restringidos. Si los permisos no son los esperados, Senda debe avisar y negarse a usar el archivo.
- Quickshell depende del binario `senda` para los datos del calendario. Si el binario no está disponible, la tarjeta muestra un aviso.
- Añadir otros proveedores de calendario requerirá un nuevo ADR, porque el modelo de tokens y ámbitos es específico de Google.
