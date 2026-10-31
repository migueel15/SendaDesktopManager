# Google Calendar

El dashboard muestra los eventos de tu cuenta de Google. Senda solo pide permisos de lectura y guarda el refresh token en el keyring de tu sesión mediante Secret Service.

## Requisitos

Para guardar tokens necesitas `secret-tool` (paquete `libsecret`) y un proveedor de Secret Service, como GNOME Keyring o KWallet con esa interfaz habilitada. Funciona en Wayland y X11; el compositor por sí solo no proporciona un keyring.

En Arch Linux con Hyprland puedes instalar:

```sh
sudo pacman -S --needed libsecret gnome-keyring seahorse
```

Abre **Contraseñas y claves** (`seahorse`), crea o configura un almacén predeterminado con contraseña y desbloquéalo antes de conectar Google. GNOME Keyring puede activarse por D-Bus; el desbloqueo automático depende de la integración PAM de tu inicio de sesión. No necesitas instalar GNOME como escritorio ni iniciar otro proveedor si ya usas KWallet compatible. No dejes vacía la contraseña del almacén: el cifrado depende de su configuración.

Si falta el servicio, está bloqueado y no se puede desbloquear, o falla la operación, Senda muestra un error y no guarda un token nuevo en texto plano. La instalación de paquetes no configura por sí sola el desbloqueo de la sesión. Véase el [manual de secret-tool](https://man.archlinux.org/man/secret-tool.1.en).

Las releases oficiales de Senda incluyen su propio cliente OAuth. Si usas una release, no necesitas crear nada: abre el panel y pulsa **Conectar con Google**.

Si compilas Senda desde el código fuente, o quieres usar tu propio cliente, necesitas uno en Google Cloud:

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

1. Abre la ventana de ajustes con `senda settings` o desde el dashboard.
2. Solo si usas tu propio cliente: introduce el ID y el secreto y pulsa Enter en el secreto o **Guardar credenciales**. El secreto no se vuelve a mostrar.
3. Pulsa **Conectar con Google**. Se abre el navegador; acepta el acceso. Senda recibe la respuesta en `127.0.0.1` y guarda el refresh token.
4. Activa los interruptores de los calendarios a mostrar. Cada cambio se guarda al instante. Sin selección propia se usan los calendarios marcados por Google.

También puedes hacerlo desde la terminal con `senda calendar login`, `senda calendar status` y `senda calendar logout`.

## Qué se guarda

| Dato | Dónde | Permisos |
|---|---|---|
| ID de tu cliente (opcional) | `$XDG_CONFIG_HOME/senda/config` | Preferencia que se comparte con la configuración |
| Secreto de tu cliente (opcional) | Keyring; sin keyring, `$XDG_STATE_HOME/senda/secrets` | Proveedor del keyring, o archivo `0600` sin cifrar |
| Cliente incluido en la release | Dentro del binario, no editable | — |
| Refresh token | Keyring de Secret Service, entrada «Senda Google Calendar» | Cifrado y acceso gestionados por el proveedor |
| Access token | Solo en memoria, renovado automáticamente | — |

El token se envía a `secret-tool` por la entrada estándar, nunca como argumento de proceso. La entrada se identifica por la aplicación, el tipo de token y un identificador derivado de la ruta de estado; no incluye el correo del usuario.

Las instalaciones anteriores se migran al primer acceso a la conexión: Senda lee el archivo `$XDG_STATE_HOME/senda/google-calendar.json` (por defecto `~/.local/state/senda/google-calendar.json`), lo guarda en el keyring y solo después elimina el JSON. Rechaza archivos antiguos con permisos abiertos a otros usuarios. Si falla la migración, conserva el archivo y comunica el error. Borrar el archivo no elimina posibles copias de seguridad previas.

## Desconectar

`senda calendar logout` necesita acceso al keyring: elimina su entrada y cualquier archivo heredado antes de solicitar la revocación en Google. Si la revocación falla, el token local ya está eliminado y el comando lo indica. Puedes completar la revocación desde las conexiones de tu cuenta de Google. Desinstalar Senda no elimina automáticamente la entrada del keyring: desconecta antes.
