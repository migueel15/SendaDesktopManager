# Google Calendar

El dashboard muestra los eventos de tu cuenta de Google. Senda solo pide permisos de lectura y guarda un refresh token en tu equipo.

## Requisitos

Necesitas un cliente OAuth propio en Google Cloud. Senda no incluye ninguno.

1. En [Google Cloud Console](https://console.cloud.google.com), crea un proyecto.
2. Activa **Google Calendar API** en *APIs y servicios → Biblioteca*.
3. Configura la pantalla de consentimiento en *Google Auth Platform → Público*:
   - Tipo de usuario: **Externo**.
   - En *Acceso a los datos*, añade estos dos ámbitos de solo lectura:
     - `https://www.googleapis.com/auth/calendar.events.readonly`
     - `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
   - En *Usuarios de prueba*, añade tu cuenta de Google.
   - Pulsa **Publicar aplicación** y elige *En producción*. Si la dejas en "Testing", Google caduca el inicio de sesión a los 7 días.
4. En *Clientes*, crea un cliente de tipo **Aplicación de escritorio** y copia el ID y el secreto.

Google mostrará un aviso de aplicación no verificada al iniciar sesión. Para uso personal, pulsa *Configuración avanzada* y después *Ir a Senda*.

## Conectar la cuenta

1. Abre el panel de configuración con `senda settings` o desde el dashboard.
2. Introduce el ID y el secreto del cliente y pulsa **Guardar credenciales**. El secreto no se vuelve a mostrar.
3. Pulsa **Conectar con Google**. Se abre el navegador; acepta el acceso. Senda recibe la respuesta en `127.0.0.1` y guarda el refresh token.
4. Elige los calendarios a mostrar y pulsa **Guardar calendarios**.

También puedes hacerlo desde la terminal con `senda calendar login`, `senda calendar status` y `senda calendar logout`.

## Qué se guarda

| Dato | Dónde | Permisos |
|---|---|---|
| ID y secreto del cliente | `$XDG_CONFIG_HOME/senda/config` | `0600` |
| Refresh token | `$XDG_STATE_HOME/senda/google-calendar.json` | `0600` |
| Access token | Solo en memoria, renovado automáticamente | — |

Si el archivo del token tiene permisos más abiertos que `0600`, Senda se niega a usarlo.

## Desconectar

`senda calendar logout` revoca el token en Google y borra el archivo local. Si la revocación falla, el archivo local se borra igualmente y el comando lo indica.
