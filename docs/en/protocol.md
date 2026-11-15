# Message Protocol

Shared source of truth for **Godot**, the **web controller** and the **backend**. It describes the behavior implemented in `backend/src/`. **Agree on every protocol change here first**, then implement it in all three components.

- Transport: one WebSocket at `/ws` (`ws://<host>/ws`, or `wss://` when the page uses HTTPS).
- Format: JSON text messages. Every message has a `type` field.
- The **first registration message** determines connection identity: `create_room` registers a host (Godot); `join_room` or `resume_player` registers a player (controller). A registered connection cannot register again (`already_registered`).
- Node **never trusts a `playerId` sent by a phone**; it derives player identity from the connection.

## Message index

| Message | Direction | Validator |
|---|---|---|
| `create_room` | Godot → Node | Node |
| `room_created` | Node → Godot | — |
| `join_room` | Controller → Node | Node |
| `joined` | Node → Controller | — |
| `select_role` | Controller → Node | Node |
| `leave_room` | Controller → Node | Node |
| `left_room` | Node → Controller | — |
| `lobby_state` | Node → Godot and controllers | — |
| `start_game` | Godot → Node | Node |
| `game_started` | Node → Godot and controllers | — |
| `controller_view` | Godot → Node → Controller | Node (shape) |
| `choose` | Controller → Node → Godot | Node (shape and identity); **Godot** (everything else) |
| `continue` | Controller → Node → Godot | Node (shape and identity); **Godot** (whether everyone confirmed) |
| `choice_result` | Godot → Node | Node (shape) |
| `resume_player` | Controller → Node | Node |
| `finish_game` | Godot → Node | Node |
| `room_closed` | Node → controllers | — |
| `error` | Node → message sender | — |

**Authority split:** Node validates message shape, identity, room and role. **Godot validates game rules**: whether an event is open, an option exists, a player may decide, duplicates and consequences. Node does not inspect `eventId` or `optionId`.

## Messages

### `create_room` and `room_created`

Godot creates a room and registers this connection as host:

```json
{ "type": "create_room" }
```

Node replies with `room_created`, followed immediately by an empty `lobby_state`:

```json
{ "type": "room_created", "code": "K7MP", "hostToken": "Zm9v…" }
```

`code` is a unique four-character code using `A-Z` and `2-9` (excluding `0`, `O`, `1`, `I`). `hostToken` is a host credential; **the MVP does not use it** because host reconnection is not implemented.

### `join_room` and `joined`

The controller requests to join:

```json
{ "type": "join_room", "code": "K7MP", "name": "Ana" }
```

`code` accepts up to 8 characters, case-insensitively. `name` must contain 1–24 characters after trimming spaces and need not be unique. Errors: `invalid_code`, `invalid_name`, `room_not_found`, `room_full` (four players already), `game_already_started`, `already_registered`.

On success:

```json
{ "type": "joined", "code": "K7MP", "playerId": "p2", "resumeToken": "c2Vj…" }
```

`playerId` values (`p1`, `p2`…) follow arrival order and are not reused. The controller must store `code` and `resumeToken` in `localStorage`. Node then broadcasts `lobby_state` to the room.

### `select_role`

The controller requests or changes its primary role, only in the lobby:

```json
{ "type": "select_role", "role": "engineer" }
```

Roles: `engineer`, `biologist`, `doctor`, `generalist`. The first player also receives `commander: true`; this additional ability does not occupy a role, and its vote breaks a second tie. Changing role frees the previous one.

There is no direct success response; everyone receives an updated `lobby_state`. Errors: `invalid_role`, `role_taken`, `not_in_lobby`, `not_player`.

### `leave_room` and `left_room`

Players may leave **only in the lobby**. During a game they retain their seat when disconnected and can return with `resume_player`.

```json
{ "type": "leave_room" }
```

Node deletes the player, frees the role and invalidates their `resumeToken`, then replies with `left_room` and broadcasts an updated `lobby_state`. If the departing player was Commander, that ability passes to the next player in arrival order. The connection is unregistered and may send another `join_room`.

```json
{ "type": "left_room" }
```

The controller clears the saved credentials and returns to the entry screen. Errors: `not_player`, `not_in_lobby`.

### `lobby_state`

Complete room state sent to Godot and controllers:

```json
{
  "type": "lobby_state",
  "code": "K7MP",
  "status": "lobby",
  "players": [
    { "id": "p1", "name": "Ana", "role": "engineer", "commander": true, "connected": true },
    { "id": "p2", "name": "Luis", "role": null, "commander": false, "connected": false }
  ]
}
```

`status` is `lobby`, `playing` or `finished`; `role` is `null` until selected. It is sent on room creation (host only), join, leave, role change, disconnect or reconnect. It is a **full state, not a diff**: replace local state. It contains no tokens.

### `start_game` and `game_started`

Godot requests transition from `lobby` to `playing`:

```json
{ "type": "start_game" }
```

The sender must be host, the room must be in the lobby, there must be 1–4 players and everyone must have a role. Errors: `not_host`, `not_in_lobby`, `no_players`, `players_without_role`.

Node sends connected controllers and Godot:

```json
{ "type": "game_started", "players": [{ "id": "p1", "name": "Ana", "role": "engineer", "commander": true, "connected": true }] }
```

From then on, new players and role changes are rejected. Godot uses this player list to determine which roles are present.

### `controller_view`

Godot tells a player's phone what to display. The Godot → Node message includes `playerId`:

```json
{
  "type": "controller_view",
  "playerId": "p2",
  "view": {
    "screen": "choice",
    "eventId": "storm-01#1",
    "title": "A solar storm is coming",
    "prompt": "What do you suggest?",
    "options": [
      { "id": "shelter", "label": "Protect the crew" },
      { "id": "continue", "label": "Continue working" }
    ]
  }
}
```

Node forwards it to that connection without `playerId`:

```json
{ "type": "controller_view", "view": { "screen": "choice", "eventId": "storm-01#1", "…": "…" } }
```

Node stores `view` as the player's `lastView` and sends it again after reconnection. A disconnected player does not receive it immediately, but it is still stored. Errors to Godot: `not_host`, `unknown_player`, `invalid_view`.

Node only requires `view` to be an object. Godot/controller screens are:

| `screen` | Fields | Controller display |
|---|---|---|
| `choice` | `eventId`, `title`, `prompt`, `options[{id,label,detail?,disabled?,reason?}]` | Question and buttons. |
| `waiting` | `title`, `text?` | Waiting message, no actions. |
| `result` | `title`, `text`, `canContinue?` | Decision consequences. `canContinue` (optional boolean): when `false` the controller hides the continue button (e.g. when the game is over); when missing or `true`, it shows it. |

Optional option fields are passed through as-is: `detail` (cost shown below label), `disabled` (boolean; dim the button) and `reason` (why it is unavailable). Missing optional fields mean a normal `{id, label}` option. Godot must reject a `choose` for an option marked disabled (`invalid_option`).

### `choose`

The controller sends a choice:

```json
{ "type": "choose", "actionId": "p2-action-17", "eventId": "storm-01#1", "optionId": "shelter" }
```

Node adds identity from the **connection**, not from the phone:

```json
{ "type": "choose", "playerId": "p2", "role": "engineer", "actionId": "p2-action-17", "eventId": "storm-01#1", "optionId": "shelter" }
```

The controller generates an `actionId` per **logical press** and reuses it on retries. Node only rejects `not_player`, `not_playing` (game has not started) or `invalid_choice` (missing fields). **Godot decides everything else** and responds with `choice_result`.

### `choice_result`

Godot reports acceptance to Node. Node validates sender and shape but does not forward the result to the controller: Godot displays the outcome on its main screen and sends the next `controller_view`.

```json
{ "type": "choice_result", "playerId": "p2", "actionId": "p2-action-17", "accepted": true }
{ "type": "choice_result", "playerId": "p2", "actionId": "p2-action-18", "accepted": false, "reason": "event_closed" }
```

Godot rejection reasons: `event_closed`, `not_eligible`, `invalid_option`, `already_decided`. Repeated `actionId` values must receive **the same response** as the first request, without applying effects again; Godot guarantees this (see [Godot networking](godot/networking.md)).

### `continue`

The controller confirms it is ready to advance after a result:

```json
{ "type": "continue", "actionId": "p2-continue-17" }
```

Node adds `playerId` and `role` from the connection. Godot counts confirmations from connected players and calls `continue_after_resolution()` only after everyone has confirmed. The host can advance directly from the main screen. Node errors: `not_player`, `invalid_continue` (missing `actionId`).

### `resume_player`

The controller restores a session after a disconnect, reload, network change or locked screen:

```json
{ "type": "resume_player", "code": "K7MP", "resumeToken": "c2Vj…" }
```

To the new connection, Node sends in this order: (1) `joined` with the same IDs/token, (2) current `lobby_state`, (3) `controller_view` with `lastView`, if available. Then it broadcasts `lobby_state` to the room (`connected: true`). A previous live connection for the same player is closed with code `4000`, reason `replaced`. Works during a game. Errors: `invalid_token`, `room_not_found`, `already_registered`.

### `finish_game`, `room_closed` and `error`

Godot ends the game:

```json
{ "type": "finish_game" }
```

Node sends `room_closed` with `reason: "game_finished"` to controllers and deletes the room. Error: `not_host`.

```json
{ "type": "room_closed", "reason": "host_disconnected" }
```

Reasons are `host_disconnected` or `game_finished`; the room no longer exists, so controllers must clear `resumeToken` and offer a way back to the start.

Node reports a rejected message to its sender:

```json
{ "type": "error", "code": "role_taken", "message": "role_taken", "requestType": "select_role" }
```

`message` currently equals `code`; clients translate `code` to text. `requestType` is omitted when the message fails parsing or field validation (`invalid_json`, `missing_type`, `unknown_type` and the `invalid_*` codes in the table).

| Error code | Meaning |
|---|---|
| `invalid_json`, `missing_type`, `unknown_type` | Message could not be interpreted. |
| `invalid_code`, `invalid_name`, `invalid_role`, `invalid_token`, `invalid_choice`, `invalid_continue`, `invalid_view`, `invalid_result` | Missing or invalid fields. |
| `already_registered` | Connection already has a room. |
| `not_host` / `not_player` | Message sent by the wrong connection type. |
| `room_not_found`, `room_full`, `game_already_started` | `join_room` / `resume_player` failure. |
| `role_taken`, `not_in_lobby` | `select_role`; `not_in_lobby` also applies to `start_game` and `leave_room`. |
| `no_players`, `players_without_role` | `start_game` failure. |
| `not_playing` | `choose` before game start. |
| `unknown_player` | `controller_view` / `choice_result` references an unknown player. |

## Room rules summary

- Maximum four players; one player per role; roles change only in the lobby.
- Start with 1–4 players, all assigned a role.
- A disconnected phone retains its player and role (`connected: false`). In the lobby it can leave with `leave_room`; after game start it cannot leave, only reconnect.
- If the **host** disconnects, the room closes and controllers receive `room_closed`. Host reconnection is not supported in the MVP.
- Rooms are in memory and disappear when Node restarts.
- Heartbeat: Node sends a WebSocket ping every 15 seconds and terminates unresponsive connections. A phone without network is marked disconnected after about 15–30 seconds.

## Acceptance criteria

- [ ] Milestone 1: a real phone button changes text in Godot exported to web.
- [x] Two open rooms receive only their own decisions. *(backend test)*
- [x] A fifth player cannot join and a role cannot be reserved twice. *(backend test)*
- [ ] A double press never applies a consequence twice. *(Godot)*
- [x] A phone can reconnect and restore its role and screen. *(backend/controller tests; real phones still need testing)*
- [ ] A choice for an old event is rejected. *(Godot)*
- [x] Host disconnection is communicated to controllers. *(backend test)*
- [ ] The LAN demo works with all assets available locally.
