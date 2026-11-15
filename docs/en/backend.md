# Backend

Node server that manages **rooms, identities, roles and connections**, and forwards messages between Godot (the host) and the controllers. It does not know the game rules. Contract: [protocol.md](protocol.md).

## Technologies

| Component | Choice |
|---|---|
| Runtime | Node ≥ 20, ES modules (`"type": "module"`) |
| HTTP | Express 5 (only `/api/health`) |
| WebSocket | `ws` on `/ws`, using the same HTTP server |
| Identifiers | `node:crypto` (`randomInt` for codes, `randomBytes` for tokens) |
| Tests | `node:test` + `node:assert` |
| State | In-memory `Map` |

## Structure

```text
backend/
  src/
    server.js     createApp(): Express + WebSocketServer, one handler per message, heartbeat
    rooms.js      In-memory Room/Player, codes and tokens, role and capacity rules
    protocol.js   Constants (ROLES, MAX_PLAYERS), input validation, send/sendError
    log.js        Raw message logger (LOG_MESSAGES=1)
  test/
    server.test.js  Integration tests with real WebSocket clients
  Dockerfile
```

## Run

```bash
cd backend
npm install
npm run dev     # node --watch, port 3000 (or $PORT)
npm test        # integration tests
```

Health check: `curl http://localhost:3000/api/health` → `{"ok":true,"rooms":0}`.

**Message logging:** with `LOG_MESSAGES=1`, the backend prints every received (`←`) and sent (`→`) message exactly as transmitted, together with the connection (`host K7MP`, `K7MP/p1`, or `unregistered` if it has not created or joined a room yet). Running `npm run dev` from the repository root enables it by default (`LOG_MESSAGES=0` disables it). Tokens are also shown: development only.

```text
← host K7MP     {"type":"start_game"}
→ host K7MP     {"type":"game_started","players":[...]}
→ K7MP/p1       {"type":"game_started","players":[...]}
← K7MP/p1       {"type":"choose","actionId":"p1-x8f2","eventId":"storm#1","optionId":"shelter"}
→ host K7MP     {"type":"choose","playerId":"p1","role":"engineer",...}
```

**Windows:** if startup fails with `listen EACCES` on port 3000, Hyper-V/WSL may have reserved a range that includes it (`netsh interface ipv4 show excludedportrange protocol=tcp`). Use another port with `PORT=8787 npm run dev` and set `BACKEND_PORT=8787` when starting the controller. This does not happen inside Docker's Linux container.

## Data model

```text
Room    { code, status: lobby|playing|finished, hostConnection, hostToken,
          players: Map<playerId, Player>, nextPlayer }
Player  { id, name, role, commander, resumeToken, connection, connected, lastView }
```

- Four-character codes use `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` and are regenerated if they collide with a live room.
- `resumeToken` and `hostToken` are 24 random bytes encoded as base64url. **A room code is not a credential.**
- `lobby_state` exposes only `id`, `name`, `role` and `connected`; it never exposes tokens or connections.

## Connection context

Each connection has a `{ kind, room, player }` context:

| `kind` | Set by | May send |
|---|---|---|
| `null` | On connection | `create_room`, `join_room`, `resume_player` |
| `host` | `create_room` | `start_game`, `controller_view`, `choice_result`, `finish_game` |
| `player` | `join_room` / `resume_player` | `select_role`, `leave_room`, `choose`, `continue` |

A message sent by the wrong connection type returns `not_host` / `not_player`. Player identity always comes from the connection context: `choose` ignores any `playerId` sent by the phone.

## Internal flow

- **Host registration:** `create_room` creates the room, stores the connection and responds with `room_created` followed by `lobby_state`.
- **Joining:** `join_room` creates a `Player` without a role. The first player also receives `commander: true`; they still choose a primary role. `lobby_state` is broadcast.
- **Roles:** `selectRole` checks that the room is in the lobby and no other player has the requested role.
- **Starting:** requires 1–4 players, all with roles; changes status to `playing` and sends `game_started`.
- **Views:** `controller_view` stores `lastView` and sends it if the player is connected.
- **Choice:** `choose` is forwarded to the host with `playerId` and `role` added. Node does **not** inspect `eventId` or `optionId`.
- **Result:** `choice_result` is validated for the host, but not forwarded to the controller; Godot communicates the result through the next `controller_view`.
- **Reconnection:** `resume_player` looks up the token, replaces the connection (closing the old one with `4000 replaced`) and resends `joined`, `lobby_state` and `lastView`.
- **Phone disconnect:** sets `connected = false`, retains the role and broadcasts `lobby_state`. Only the current connection may mark the player disconnected, so a replaced connection cannot do so.
- **Host disconnect:** sends `room_closed (host_disconnected)` and deletes the room.
- **Game over:** `finish_game` sends `room_closed (game_finished)` and deletes the room.

## Heartbeat

Every 15 seconds the server pings each connection. If it has not received a pong since the previous ping, it terminates that connection and triggers the disconnect flow. Browsers respond to pings automatically.

## Tests

`test/server.test.js` starts the server on an available port and uses real `ws` clients. It covers `/api/health`, room creation, capacity of four, duplicate roles, room isolation, `playerId` spoofing, view/result flow, host permissions, reconnection with role and view restoration, invalid tokens, host closure and malformed messages.

It does not cover decisions owned by Godot (duplicates, stale events, voting) or the LAN/Nginx setup.

## Known MVP limitations

- All state is in memory; restarting the backend loses the rooms.
- No host reconnection (`hostToken` is issued but not yet used).
- A disconnected phone keeps its place until the room closes. To leave completely, send `leave_room` from the lobby; Node removes the player, frees the role and transfers Commander to the next player if necessary.
- No room count or message-rate limits (sufficient for a LAN demo).
- `message` in an `error` equals `code`; clients are responsible for translating it to user-facing text.
