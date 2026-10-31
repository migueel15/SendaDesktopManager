# Autenticación polkit

La shell incluye un agente polkit. Cuando una aplicación pide permisos de administrador, aparece una extensión bajo la barra superior con el mensaje de la aplicación, el identificador de la acción y la cuenta que autoriza. Enter o «Autorizar» envían la contraseña; Escape o «Cancelar» cierran la petición.

Polkit no indica al diálogo qué proceso hizo la petición, así que se muestra el mensaje y la acción que aporta.

Solo puede haber un agente por sesión. Si otro ya está registrado, como `hyprpolkitagent`, Senda no muestra nada y sigue funcionando el del usuario. Para usar el de Senda, deja de iniciar ese agente y reinicia la shell con `systemctl --user restart senda`.
