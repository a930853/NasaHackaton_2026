# Mando web (controller)

App **Vue 3 + Vite + Tailwind CSS 4** (JavaScript) que usa cada jugador en su móvil. Habla con el backend por el WebSocket `/ws` según el [contrato de mensajes](protocol.md). El mando **solo envía elecciones**: no conoce reglas ni recursos del juego.

## Ejecutar

La forma rápida, desde la raíz del repo: `npm install && npm run dev`. Levanta backend, mando y landing, con el log de mensajes del backend activado (ver el [README](../../README.md#run-the-development-environment)). Hace falta un anfitrión (Godot) que cree la sala.

Por separado:

```bash
# 1. Backend
cd backend && npm install && npm run dev        # :3000

# 2. Mando
cd controller && npm install && npm run dev     # http://localhost:5173/controller/
npm test                                        # tests del store contra el backend real
npm run build                                   # genera ../dist/controller/
```

- `npm run dev` escucha también en la LAN: abrid desde el móvil `http://<IP-del-PC>:5173/controller/`.
- Vite reenvía `/ws` al backend, así que el código usa siempre `location.host` (igual que detrás de Nginx).
- **Windows y el puerto 3000:** Hyper-V/WSL a veces reservan un rango que incluye el 3000 (`listen EACCES`). Comprobadlo con `netsh interface ipv4 show excludedportrange protocol=tcp` y usad otro puerto: `PORT=8787 npm run dev` en `backend/` y `BACKEND_PORT=8787 npm run dev` en `controller/`.
- Los tests importan `backend/src/server.js`: necesitan `npm install` hecho también en `backend/`.

## Rutas

La app se sirve bajo `/controller/` (`base` de Vite y del router).

| Ruta | Uso |
|---|---|
| `/controller/` | Entrada normal: pide código y nombre; después, elegir rol en pantalla. |
| `/controller/?room=K7MP` | Igual, con el código precargado (lo que abre el QR). |
| `/controller/engineer` · `/biologist` · `/doctor` · `/generalist` | **Entrada directa a un rol** (tablero físico con NFC). Pide código y nombre si no viene `?room=` y reserva ese rol al entrar. El Comandante es una capacidad adicional del primer jugador. |
| `/controller/<rol>?room=K7MP` | Entrada directa con sala y rol. |

La ruta expresa la **intención** del jugador; el rol real lo confirma el backend en `lobby_state`:

- En el lobby, entrar en `/controller/<rol>` (por botón o NFC) envía `select_role`. Si el rol está ocupado, vuelve a `/controller/` con el aviso.
- Una vez empezada la partida, los roles quedan fijos y la ruta se corrige al rol confirmado.
- Si un jugador recupera la sesión desde `/controller/`, se le lleva a la ruta de su rol.

**Tablero NFC:** cada etiqueta guarda la URL del rol sin sala, p. ej. `http://192.168.1.50/controller/engineer`. Al acercar el móvil, el jugador escribe el código que ve en la pantalla y su nombre, y entra directamente con ese rol. Nginx debe devolver `index.html` para cualquier ruta bajo `/controller/` (ver [Despliegue](#despliegue)).

## Estructura

```text
controller/
  index.html
  vite.config.js           base /controller/, salida ../dist/controller, proxy /ws, Tailwind
  src/
    main.js                crea la sesión, la inyecta (provide) y conecta al resolverse la URL
    router.js              rutas home + una por rol (meta.role)
    App.vue                solo <RouterView />
    roles.js               datos de los roles principales y la capacidad de Comandante
    messages.js            textos para los códigos de error, rechazo y cierre
    styles.css             Tailwind: tema (@theme) y clases compartidas
    net/socket.js          WebSocket: URL desde location, reconexión con backoff
    stores/session.js      estado reactivo de la sesión y acciones (join, selectRole, choose…)
    views/
      ControllerView.vue   orquesta: estado de la sesión + ruta → pantalla
      EnterView.vue        código + nombre
      RolePicker.vue       selección de rol del lobby
    components/
      ChoiceView.vue       pregunta y opciones (controller_view "choice")
      StatusCard.vue       espera, decisión registrada, resultado, sala cerrada
      CrewList.vue         tripulación (nombre, rol, conexión)
      DevicePlate.vue      placa de identidad: casco del color del rol, nombre y código de sala
    assets/                casco, foto de Marte y tornillo (copiados de game/Images)
  test/session.test.js     tests del store contra el backend real
```

Reglas de la arquitectura:

- **Solo `net/socket.js` toca el WebSocket.** Solo `stores/session.js` interpreta mensajes.
- Las vistas leen `session.state` y llaman a acciones; no construyen mensajes.
- **El contenido de las pantallas de juego lo dicta Godot** (`controller_view`). El mando no tiene preguntas ni opciones propias.

## Estado de la sesión

`session.state` (reactivo):

| Campo | Valores |
|---|---|
| `connection` | `connecting` · `online` · `offline` (reconectando) · `replaced` (otro dispositivo tomó la sesión) |
| `phase` | `connecting` · `enter` · `joining` · `lobby` · `playing` · `closed` |
| `code`, `playerId`, `name`, `role`, `commander` | Identidad confirmada por el backend |
| `players`, `roomStatus` | Último `lobby_state` |
| `view` | Última `controller_view` |
| `choice` | `{ status: idle · sending · registered · rejected, eventId, optionId, reason }` |
| `error` | `{ code, requestType, seq }`; `seq` cambia en cada error |
| `closedReason` | Motivo de `room_closed` |

Pantalla según el estado (`ControllerView.vue`):

```text
connection = replaced                → «Opened somewhere else» + «Use this device»
phase = connecting | joining         → «Connecting…»
phase = enter                        → EnterView + «Back to home» (la landing, /)
phase = closed                       → «Room closed» + «Join another room»
phase = lobby, sin rol en la ruta    → RolePicker + «Keep my job» (si ya tenía rol)
phase = lobby, con rol               → «Saving your job…» o «You are in!» + «Change job» y «Leave the room»
phase = playing
  view = null                        → «Lift-off!»
  view.screen = choice               → ChoiceView (o «Vote sent!» si ya se aceptó)
  view.screen = result               → resultado + «Continue»
  view.screen = waiting / otro       → espera
```

**Salidas (ir atrás):** antes de entrar, «Back to home»; al elegir rol, «Keep my job» si ya tenía uno; con el rol guardado, «Change job» y «Leave the room». «Leave the room» envía `leave_room` ([protocolo](protocol.md#leave_room)): Node borra al jugador y libera su rol, y el mando vuelve a la entrada con el código precargado. Con la partida empezada no se puede salir.

## Recuperación y elecciones

- Al recibir `joined` se guarda en `localStorage` (`nasa.controller.session`) el código, el `resumeToken` y el `playerId`. Al recargar o reconectar se envía `resume_player`.
- Si el código de `?room=` no coincide con el guardado, la sesión guardada se descarta (es otra partida).
- Si `resume_player` falla (`invalid_token`, `room_not_found`) se borra lo guardado y se vuelve a la entrada.
- Al pulsar una opción se crea un `actionId` (`<playerId>-<aleatorio>`, con `crypto.getRandomValues`, que funciona en http) y se guarda como **pendiente**. Los botones se bloquean y se muestra «Enviando…».
- Si se recarga o se corta la red antes del `choice_result`, al recuperar la sesión llega la misma vista y se **reenvía el mismo `actionId`**. Godot responde igual sin repetir efectos.
- El mando no recibe `choice_result`: permanece enviando hasta que Godot mande una nueva `controller_view`, que puede ser de resultado, espera o una nueva pregunta.
- En una vista `result` con `canContinue: true`, el botón `Continue` envía una confirmación; la partida avanza cuando todos los mandos conectados confirman o el anfitrión pulsa el botón de la pantalla principal.
- Llegar a una vista que no es la de la elección pendiente descarta la elección pendiente.
- `room_closed` borra las credenciales. «Volver al inicio» abre una conexión nueva (la anterior queda asociada a la sala cerrada).
- Si otro dispositivo recupera la misma sesión, Node cierra esta conexión con el código `4000`: el mando no reconecta solo y ofrece «Usar este dispositivo».

## Estilos

- El mando es un **aparato de la cabina del juego** sobre la foto de Marte del menú: carcasa (`device`) con tornillos recortados de `hud_frame.png`, placa de identidad (`DevicePlate.vue`, con el casco del juego teñido del color del rol), pantallas con bisel (`screen`) y teclas que se hunden al pulsar (`key`; `key-quiet` para acciones secundarias, `key-off` para opciones bloqueadas).
- Tailwind 4 con `@tailwindcss/vite`. El tema (`@theme` en `styles.css`) define la paleta (`hull`, `ink`, `screen`, `glass`, `key-red/cyan/orange/purple`…) y las fuentes: `font-display` Sixtyfour (la del título del juego, solo textos cortos) y `font-sans` Chakra Petch.
- El color del rol activo llega por la variable CSS `--role-color`, que fija `roleStyle()` de `roles.js`.
- Imágenes en `src/assets/` (casco, foto de Marte, tornillo), copiadas de `game/Images`.
- Fuentes empaquetadas con `@fontsource`. **Nada se carga de Internet**: la demo debe funcionar en la LAN sin conexión exterior.

## Despliegue

- `npm run build` genera `dist/controller/` (no se versiona). La imagen `web` de Docker (`deploy/web.Dockerfile`) lo compila ella misma: no hace falta hacerlo antes de levantar Compose.
- Nginx (`deploy/nginx/default.conf`; la imagen `web` copia `dist/controller/` dentro de `/srv/www`): servir el mando en `/controller/` con *fallback* a `index.html` para que funcionen las rutas de rol al entrar directamente (NFC, recarga):

```nginx
# deploy/nginx/default.conf (extracto)
root /srv/www;

# Mando (Vue). Las rutas de rol (/controller/engineer…) no existen como
# fichero: se sirve index.html y el router del mando decide.
location /controller/ {
    try_files $uri $uri/ /controller/index.html;
}
```

## Pendiente

- Probar en móviles reales (iOS Safari y Android Chrome), incluido el bloqueo de pantalla y el cambio de red.
- Pantalla de resultado final si Godot envía más campos en `view` (p. ej. recursos): ampliar el contrato primero.
