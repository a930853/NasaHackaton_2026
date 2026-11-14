# Backend

Servidor Node que gestiona **salas, identidades, roles y conexiones** y reparte mensajes entre Godot (anfitrión) y los mandos. No conoce las reglas del juego. Contrato: [protocol.md](protocol.md).

## Tecnologías

| Pieza | Elección |
|---|---|
| Runtime | Node ≥ 20, ES modules (`"type": "module"`) |
| HTTP | Express 5 (solo `/api/health`) |
| WebSocket | `ws` en `/ws`, sobre el mismo servidor HTTP |
| Identificadores | `node:crypto` (`randomInt` para códigos, `randomBytes` para tokens) |
| Tests | `node:test` + `node:assert` |
| Estado | `Map` en memoria |

## Estructura

```text
backend/
  src/
    server.js     createApp(): Express + WebSocketServer, un handler por mensaje, heartbeat
    rooms.js      Room/Player en memoria, códigos y tokens, reglas de roles y aforo
    protocol.js   Constantes (ROLES, MAX_PLAYERS), validación de entrada, send/sendError
    log.js        Log de mensajes en bruto (LOG_MESSAGES=1)
  test/
    server.test.js  Pruebas de integración con clientes WebSocket reales
  Dockerfile
```

## Ejecutar

```bash
cd backend
npm install
npm run dev     # node --watch, puerto 3000 (o $PORT)
npm test        # pruebas de integración
```

Comprobación: `curl http://localhost:3000/api/health` → `{"ok":true,"rooms":0}`.

**Log de mensajes:** con `LOG_MESSAGES=1` el backend imprime cada mensaje que recibe (`←`) y envía (`→`), tal cual viaja, junto a la conexión (`host K7MP`, `K7MP/p1` o `sin registrar` si aún no ha creado ni entrado en sala). `npm run dev` desde la raíz lo activa por defecto (`LOG_MESSAGES=0` para quitarlo). Muestra también los tokens: solo para desarrollo.

```text
← host K7MP     {"type":"start_game"}
→ host K7MP     {"type":"game_started","players":[...]}
→ K7MP/p1       {"type":"game_started","players":[...]}
← K7MP/p1       {"type":"choose","actionId":"p1-x8f2","eventId":"storm#1","optionId":"shelter"}
→ host K7MP     {"type":"choose","playerId":"p1","role":"engineer",...}
```

**Windows:** si arranca con `listen EACCES` en el 3000, Hyper-V/WSL tienen reservado un rango que lo incluye (`netsh interface ipv4 show excludedportrange protocol=tcp`). Usad otro puerto con `PORT=8787 npm run dev` y, en el mando, `BACKEND_PORT=8787 npm run dev`. Dentro de Docker no pasa: el contenedor es Linux.

## Modelo

```text
Room    { code, status: lobby|playing|finished, hostConnection, hostToken,
          players: Map<playerId, Player>, nextPlayer }
Player  { id, name, role, resumeToken, connection, connected, lastView }
```

- Códigos de 4 caracteres sobre `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, regenerados hasta que no colisionan con una sala viva.
- `resumeToken` y `hostToken`: 24 bytes aleatorios en base64url. **El código de sala no es una credencial.**
- `lobby_state` solo expone `id`, `name`, `role`, `connected`; nunca tokens ni conexiones.

## Contexto de cada conexión

Cada conexión tiene un contexto `{ kind, room, player }`:

| `kind` | Se obtiene con | Puede enviar |
|---|---|---|
| `null` | Al conectar | `create_room`, `join_room`, `resume_player` |
| `host` | `create_room` | `start_game`, `controller_view`, `choice_result`, `finish_game` |
| `player` | `join_room` / `resume_player` | `select_role`, `choose` |

Un mensaje enviado por el tipo equivocado devuelve `not_host` / `not_player`. La identidad del jugador sale siempre de este contexto: `choose` ignora cualquier `playerId` que traiga el móvil.

## Flujo interno

- **Registro de anfitrión:** `create_room` crea la sala, guarda la conexión y responde `room_created` + `lobby_state`.
- **Entrada:** `join_room` crea el `Player` (sin rol) y difunde `lobby_state`.
- **Roles:** `selectRole` comprueba que la sala está en lobby y que nadie más tiene ese rol.
- **Inicio:** exige 1–4 jugadores, todos con rol; pasa a `playing` y envía `game_started`.
- **Vistas:** `controller_view` guarda `lastView` y la entrega si el jugador está conectado.
- **Elección:** `choose` se reenvía al anfitrión añadiendo `playerId` y `role`. Node **no** mira `eventId` ni `optionId`.
- **Resultado:** `choice_result` se valida para el anfitrión, pero no se reenvía al mando; Godot comunica el resultado mediante la siguiente `controller_view`.
- **Reconexión:** `resume_player` busca el token en la sala, sustituye la conexión (cierra la antigua con `4000 replaced`), reenvía `joined`, `lobby_state` y `lastView`.
- **Desconexión de un móvil:** `connected = false`, se mantiene el rol, se difunde `lobby_state`. Solo si la conexión que se cierra es la vigente (evita que el cierre de una conexión sustituida marque al jugador como desconectado).
- **Desconexión del anfitrión:** se envía `room_closed (host_disconnected)` y se borra la sala.
- **Fin:** `finish_game` envía `room_closed (game_finished)` y borra la sala.

## Heartbeat

Cada 15 s el servidor envía un *ping* a cada conexión; si no hubo *pong* desde el ping anterior, la termina (lo que dispara el flujo de desconexión). Los navegadores responden al ping automáticamente.

## Pruebas

`test/server.test.js` levanta el servidor en un puerto libre y usa clientes `ws` reales. Cubre: `/api/health`, creación de sala, aforo de 4, rol repetido, aislamiento entre salas, suplantación de `playerId`, flujo de vistas y resultados, permisos de host, reconexión con recuperación de rol y vista, token inválido, cierre del anfitrión y mensajes mal formados.

No cubre lo que decide Godot (duplicados, eventos antiguos, votaciones) ni la LAN/Nginx.

## Límites conocidos del MVP

- Todo en memoria: reiniciar el backend pierde las salas.
- Sin reconexión del anfitrión (`hostToken` se emite pero aún no se usa).
- Sin "salir de la sala": un móvil desconectado conserva su plaza hasta que cierra la sala.
- Sin límite de salas ni de tasa de mensajes (suficiente para una demo en LAN).
- `message` en `error` es igual a `code`; la traducción a texto corresponde al cliente.
