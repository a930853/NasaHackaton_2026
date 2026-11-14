# Contrato de mensajes

Fuente de verdad compartida entre **Godot**, el **mando web** y el **backend**. Describe exactamente lo que implementa `backend/src/`. **Cualquier cambio se acuerda aquí primero** y después se aplica en las tres partes.

- Transporte: un único WebSocket en `/ws` (`ws://<host>/ws`, `wss://` si la página es https).
- Formato: JSON en mensajes de texto. Todos llevan un campo `type`.
- Quién es cada conexión lo decide el **primer mensaje de registro**: `create_room` la convierte en *anfitrión* (Godot); `join_room` o `resume_player` la convierten en *jugador* (mando). Una conexión ya registrada no puede volver a registrarse (`already_registered`).
- Node **nunca** acepta un `playerId` enviado por un móvil como identidad: la deduce de la conexión.

## Índice

| Mensaje | Dirección | Quién lo valida |
|---|---|---|
| [`create_room`](#create_room) | Godot → Node | Node |
| [`room_created`](#room_created) | Node → Godot | — |
| [`join_room`](#join_room) | Mando → Node | Node |
| [`joined`](#joined) | Node → Mando | — |
| [`select_role`](#select_role) | Mando → Node | Node |
| [`lobby_state`](#lobby_state) | Node → Godot y mandos | — |
| [`start_game`](#start_game) | Godot → Node | Node |
| [`game_started`](#game_started) | Node → Godot y mandos | — |
| [`controller_view`](#controller_view) | Godot → Node → Mando | Node (forma) |
| [`choose`](#choose) | Mando → Node → Godot | Node (forma e identidad) · **Godot** (todo lo demás) |
| [`choice_result`](#choice_result) | Godot → Node | Node (forma) |
| [`resume_player`](#resume_player) | Mando → Node | Node |
| [`finish_game`](#finish_game) | Godot → Node | Node |
| [`room_closed`](#room_closed) | Node → Mandos | — |
| [`error`](#error) | Node → emisor | — |

**Reparto de autoridad:** Node valida la *forma* del mensaje, la identidad, la sala y el rol. **Godot valida el juego**: si el evento sigue abierto, si la opción existe, si el jugador puede decidir, duplicados y consecuencias. Node no mira `eventId` ni `optionId`.

---

## Mensajes

### `create_room`
Godot → Node. Crea una sala y registra a esta conexión como anfitrión.
```json
{ "type": "create_room" }
```
Respuesta: [`room_created`](#room_created) y, justo después, un [`lobby_state`](#lobby_state) vacío.

### `room_created`
Node → Godot.
```json
{ "type": "room_created", "code": "K7MP", "hostToken": "Zm9v…" }
```
- `code`: 4 caracteres de `A-Z` y `2-9` (sin `0`, `O`, `1`, `I`). Único entre salas vivas.
- `hostToken`: credencial del anfitrión. **En el MVP no se usa** (no hay reconexión del anfitrión); se entrega para poder añadirla.

### `join_room`
Mando → Node. Pide entrar en una sala.
```json
{ "type": "join_room", "code": "K7MP", "name": "Ana" }
```
- `code`: hasta 8 caracteres, sin distinguir mayúsculas.
- `name`: 1–24 caracteres tras recortar espacios. No tiene que ser único.

Errores: `invalid_code`, `invalid_name`, `room_not_found`, `room_full` (ya hay 4), `game_already_started`, `already_registered`.

### `joined`
Node → Mando. Confirma el registro y entrega la identidad.
```json
{ "type": "joined", "code": "K7MP", "playerId": "p2", "resumeToken": "c2Vj…" }
```
- `playerId`: `p1`, `p2`… en orden de llegada a la sala. No se reutilizan.
- `resumeToken`: credencial de recuperación. El mando debe guardar `code` y `resumeToken` en `localStorage`.

Tras `joined`, Node difunde un [`lobby_state`](#lobby_state) a toda la sala.

### `select_role`
Mando → Node. Pide (o cambia) su rol. Solo en el lobby.
```json
{ "type": "select_role", "role": "engineer" }
```
Roles: `engineer`, `biologist`, `doctor`, `generalist`. Si el jugador ya tenía rol, lo cambia (libera el anterior).

Éxito: no hay respuesta directa; todos reciben un [`lobby_state`](#lobby_state). Errores: `invalid_role`, `role_taken`, `not_in_lobby`, `not_player`.

### `lobby_state`
Node → Godot y mandos. Estado completo de la sala.
```json
{
  "type": "lobby_state",
  "code": "K7MP",
  "status": "lobby",
  "players": [
    { "id": "p1", "name": "Ana",  "role": "engineer", "connected": true },
    { "id": "p2", "name": "Luis", "role": null,       "connected": false }
  ]
}
```
- `status`: `lobby` | `playing` | `finished`.
- `role` es `null` hasta que el jugador elige.
- Se envía cuando: se crea la sala (solo al anfitrión), entra un jugador, cambia un rol, un jugador se desconecta o reconecta. Un jugador que reconecta lo recibe también a título individual.
- Es un **estado completo**, no un diff: el receptor sustituye lo que tenía.
- No contiene tokens.

### `start_game`
Godot → Node. Pasa la sala de `lobby` a `playing`.
```json
{ "type": "start_game" }
```
Condiciones: ser el anfitrión, estar en lobby, haber **1–4 jugadores** y que **todos tengan rol**. Errores: `not_host`, `not_in_lobby`, `no_players`, `players_without_role`.

### `game_started`
Node → Godot y mandos conectados.
```json
{ "type": "game_started", "players": [ { "id": "p1", "name": "Ana", "role": "engineer", "connected": true } ] }
```
Desde aquí no se aceptan nuevos jugadores ni cambios de rol. La lista de `players` es la que Godot debe usar para decidir qué roles están presentes.

### `controller_view`
Godot → Node → Mando. Qué debe mostrar el móvil de un jugador.

Godot → Node (lleva `playerId`):
```json
{
  "type": "controller_view",
  "playerId": "p2",
  "view": {
    "screen": "choice",
    "eventId": "storm-01#1",
    "title": "Se aproxima una tormenta solar",
    "prompt": "¿Qué propones?",
    "options": [
      { "id": "shelter",  "label": "Refugiar a la tripulación" },
      { "id": "continue", "label": "Continuar la actividad" }
    ]
  }
}
```
Node → Mando (sin `playerId`, es para esa conexión):
```json
{ "type": "controller_view", "view": { "screen": "choice", "eventId": "storm-01#1", "…": "…" } }
```
Node **guarda `view` como `lastView`** del jugador y la reenvía al reconectar. Si el jugador está desconectado, no se entrega pero sí se guarda.

Errores para Godot: `not_host`, `unknown_player`, `invalid_view`.

El contenido de `view` es libre para Node (solo exige un objeto); el contrato entre Godot y mando es:

| `screen` | Campos | Qué muestra el mando |
|---|---|---|
| `choice` | `eventId`, `title`, `prompt`, `options[{id,label,detail?,disabled?,reason?}]` | Pregunta y botones. |
| `waiting` | `title`, `text?` | Mensaje de espera, sin acciones. |
| `result` | `title`, `text` | Consecuencias de la decisión. |

Campos opcionales de cada opción (los pone Godot; el mando los pinta tal cual, sin calcular nada):

| Campo | Tipo | Significado |
|---|---|---|
| `detail` | texto | Lo que cuesta la opción (p. ej. «Costs: Energy -5»). Se muestra bajo el `label`. |
| `disabled` | booleano | `true` si ahora no se puede elegir (p. ej. el rol está ocupado fuera de la base). El botón sale apagado. |
| `reason` | texto | Por qué está bloqueada. Se muestra en la opción apagada. |

Si faltan, la opción es una opción normal `{id, label}`. Una opción con `disabled: true` que llegue en un `choose` la rechaza Godot igualmente (`invalid_option`).

### `choose`
Mando → Node → Godot. El jugador pulsa una opción.

Mando → Node:
```json
{ "type": "choose", "actionId": "p2-action-17", "eventId": "storm-01#1", "optionId": "shelter" }
```
Node → Godot (añade la identidad de la **conexión**):
```json
{
  "type": "choose",
  "playerId": "p2",
  "role": "engineer",
  "actionId": "p2-action-17",
  "eventId": "storm-01#1",
  "optionId": "shelter"
}
```
- `actionId` lo genera el mando por **pulsación lógica** y lo **reutiliza** si reenvía.
- Node responde con error solo por: `not_player`, `not_playing` (la partida no ha empezado), `invalid_choice` (campos ausentes).
- **Todo lo demás lo decide Godot** y lo contesta con [`choice_result`](#choice_result).

### `choice_result`
Godot → Node. Resultado de una elección. Node valida el jugador y la forma, pero no lo reenvía al mando: la pantalla principal de Godot muestra el resultado y envía al mando la siguiente [`controller_view`](#controller_view).

Godot → Node:
```json
{ "type": "choice_result", "playerId": "p2", "actionId": "p2-action-17", "accepted": true }
{ "type": "choice_result", "playerId": "p2", "actionId": "p2-action-18", "accepted": false, "reason": "event_closed" }
```
Motivos de rechazo definidos por Godot: `event_closed`, `not_eligible`, `invalid_option`, `already_decided`. Node valida el mensaje, pero no entrega este resultado al mando.

Un `actionId` repetido debe recibir **la misma respuesta** que la primera vez, sin repetir efectos (lo garantiza Godot, ver [godot/red.md](godot/red.md#validar-un-choose)).

### `resume_player`
Mando → Node. Recupera una sesión tras una desconexión (recarga, cambio de red, pantalla bloqueada).
```json
{ "type": "resume_player", "code": "K7MP", "resumeToken": "c2Vj…" }
```
Respuestas, **en este orden**, solo a la conexión nueva:
1. [`joined`](#joined) (mismos `playerId` y `resumeToken`).
2. [`lobby_state`](#lobby_state) actual.
3. [`controller_view`](#controller_view) con `lastView`, si existe.

Después se difunde un `lobby_state` a la sala (el jugador vuelve a figurar `connected: true`). Si había otra conexión viva para ese jugador, se cierra con código `4000` y motivo `replaced`.

Funciona también con la partida en curso. Errores: `invalid_token`, `room_not_found`, `already_registered`.

### `finish_game`
Godot → Node. Termina la partida.
```json
{ "type": "finish_game" }
```
Los mandos reciben `room_closed` con `reason: "game_finished"` y la sala se elimina. Error: `not_host`.

### `room_closed`
Node → Mandos.
```json
{ "type": "room_closed", "reason": "host_disconnected" }
```
`reason`: `host_disconnected` (el anfitrión perdió la conexión) o `game_finished`. La sala deja de existir; el mando debe borrar su `resumeToken` y ofrecer volver al inicio.

### `error`
Node → emisor del mensaje rechazado.
```json
{ "type": "error", "code": "role_taken", "message": "role_taken", "requestType": "select_role" }
```
- `code`: ver la tabla siguiente. `message` es hoy igual a `code`; el cliente debe traducir `code` a texto propio.
- `requestType`: tipo del mensaje que falló; no aparece si el mensaje ni siquiera era un JSON con `type`.

| `code` | Cuándo |
|---|---|
| `invalid_json`, `missing_type`, `unknown_type` | El mensaje no se pudo interpretar. |
| `invalid_code`, `invalid_name`, `invalid_role`, `invalid_token`, `invalid_choice`, `invalid_view`, `invalid_result` | Faltan campos o son inválidos. |
| `already_registered` | La conexión ya tiene sala. |
| `not_host` / `not_player` | Mensaje de un tipo de conexión que no le corresponde. |
| `room_not_found`, `room_full`, `game_already_started` | `join_room` / `resume_player`. |
| `role_taken`, `not_in_lobby` | `select_role`; `not_in_lobby` también en `start_game`. |
| `no_players`, `players_without_role` | `start_game`. |
| `not_playing` | `choose` antes de empezar. |
| `unknown_player` | `controller_view` / `choice_result` con un `playerId` que no existe en la sala. |

---

## Secuencias

### Lobby
```text
Godot            Node                    Mando
  │ create_room    │                       │
  │───────────────>│                       │
  │ room_created   │                       │
  │<───────────────│                       │
  │ lobby_state    │                       │
  │<───────────────│                       │
  │   (muestra código y QR)                │
  │                │       join_room       │
  │                │<──────────────────────│
  │                │       joined          │
  │                │──────────────────────>│
  │ lobby_state    │       lobby_state     │
  │<───────────────│──────────────────────>│
  │                │       select_role     │
  │                │<──────────────────────│
  │ lobby_state    │       lobby_state     │
  │<───────────────│──────────────────────>│
  │ start_game     │                       │
  │───────────────>│                       │
  │ game_started   │       game_started    │
  │<───────────────│──────────────────────>│
```

### Decisión
```text
Godot            Node                    Mando
  │ controller_view(playerId=p2)           │
  │───────────────>│ controller_view       │
  │                │──────────────────────>│
  │                │       choose          │
  │ choose(+p2)    │<──────────────────────│
  │<───────────────│                       │
  │ (valida, registra, aplica o espera)    │
  │ choice_result  │                       │
  │───────────────>│                       │
  │ controller_view(result / waiting)      │
  │───────────────>│──────────────────────>│
```

### Reconexión de un móvil
```text
Mando(nuevo)     Node                    Godot
  │ resume_player  │                       │
  │───────────────>│                       │
  │ joined         │                       │
  │ lobby_state    │                       │
  │ controller_view(lastView)              │
  │<───────────────│  lobby_state          │
  │                │──────────────────────>│
```

---

## Reglas de sala (resumen)

- Máximo 4 jugadores; un jugador por rol; los roles solo cambian en el lobby.
- Se puede iniciar con 1–4 jugadores, siempre que todos tengan rol.
- Un móvil que se desconecta **conserva jugador y rol** (`connected: false`). No existe "salir de la sala" en el MVP.
- Si el **anfitrión** se desconecta, la sala se cierra y los mandos reciben `room_closed`. No hay reconexión del anfitrión en el MVP.
- Las salas viven en memoria: reiniciar Node las pierde.
- Heartbeat: Node envía un *ping* de WebSocket cada 15 s y termina las conexiones que no responden. Un móvil sin red se marca desconectado en unos 15–30 s.

## Notas para el mando

Implementación de referencia y detalles: [controller.md](controller.md).

- Guardar `code` y `resumeToken` en `localStorage` al recibir `joined`; al cargar la página, si existen, enviar `resume_player` en lugar de pedir el código.
- Si `resume_player` falla con `invalid_token` o `room_not_found`, borrar lo guardado y volver a la pantalla de entrada.
- Si el WebSocket se cae, reintentar con *backoff* y volver a enviar `resume_player`.
- Generar `actionId` al pulsar (p. ej. `<playerId>-action-<contador>`); reenviar **el mismo** si no llega una nueva `controller_view`.
- Pulsar → «Enviando…» y botones desactivados. Godot muestra el resultado en la pantalla principal y envía al mando la siguiente vista (`result`, `waiting` o una nueva pregunta).
- Tras `resume_player` llega `controller_view` con la vista guardada: pintarla tal cual.
- Construir la URL con `location` (`(location.protocol === 'https:' ? 'wss' : 'ws') + '://' + location.host + '/ws'`). Sin IPs fijas.

## Criterios de aceptación

- [ ] Hito 1: un botón real en un móvil cambia un texto en Godot exportado a web.
- [x] Dos salas abiertas reciben únicamente sus propias decisiones. *(test de backend)*
- [x] No pueden entrar cinco jugadores ni reservar el mismo rol dos veces. *(test de backend)*
- [ ] Una doble pulsación no aplica dos veces una consecuencia. *(Godot)*
- [x] Un móvil puede reconectar y recuperar su rol y pantalla. *(tests de backend y del mando; falta probar en móviles reales)*
- [ ] Una elección de un evento anterior se rechaza. *(Godot)*
- [x] El cierre del anfitrión se comunica a los mandos. *(test de backend)*
- [ ] La demo funciona en la LAN con todos sus archivos disponibles localmente.
