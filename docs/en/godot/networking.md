# Godot Networking: Backend and Phones

How to connect `game/` to the backend using the [message protocol](../protocol.md). Other game systems (managers, state machine and `events.json`) are described in [architecture.md](architecture.md).

## Implementation status in `game/`

The real game is connected to the backend and web controller:

| Component | File | Purpose |
|---|---|---|
| `Net` autoload | `game/Scripts/net.gd` | Only WebSocket client. Emits network signals through `Events`; exposes `create_room()`, `start_game()`, `send_view()`, `send_result()`, `finish_game()`. |
| `PhoneBridge` autoload | `game/Scripts/phone_bridge.gd` | Connects `TurnManager` to phones: sends each player's `controller_view`, **validates** each `choose` (current event, player, option, duplicate `actionId`) and always responds with `choice_result`. |
| Lobby | `game/Scripts/main_menu.gd` (`Lobby` node in `Main_menu.tscn`) | “Start Game” offers **Play solo** or **Play multiplayer**. Multiplayer connects, creates a room and shows code, controller address and players/roles. “Start expedition” requires ≥1 player and roles for all. “Play solo instead” and “Back” leave the lobby. A missing server is detected after 4 s. |
| Signals | `game/Scripts/events.gd` | `net_connected`, `net_disconnected`, `net_connection_failed`, `room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `room_closed`, `net_error`. |

The lobby uses the game's visual style: blue button frame, role-color helmet cards (four slots, dimmed empty slots and Commander marked), highlighted room code and QR on a white panel with blue frame.

Flow: menu → lobby (room created, phones join/select roles) → `start_game` → intro → game. For each event, `TurnManager` emits `event_presented`; `PhoneBridge` sends **all options** to each phone (`TurnManager.controller_view_for(role)`, with `detail` for costs and `disabled`/`reason` for busy roles). After resolution all phones receive a `result` view. Returning to the menu closes the room with `finish_game`.

Implementation decisions:

- **Server URL:** in web builds, use `location` (never a hard-coded IP). In the editor, `ws://localhost:3000/ws`; override with `--ws-url=ws://localhost:3100/ws` or `NASA_WS_URL`.
- **Displayed controller address:** web uses `location.origin`; editor uses `http://localhost:5173` (Vite). The lobby warns if it contains `localhost`.
- **QR:** multiplayer lobby displays it beside instructions using `Net.controller_url(code)`. `game/Scripts/qr_code.gd` generates QR in GDScript without dependencies (byte mode, correction M, versions 1–10, up to 213 bytes). Keep the text code and URL visible as a fallback; the landing page also allows manual entry.
- **Everyone votes on every option:** each phone receives all options; role-owned options are prefixed with the role and occupy that character. This avoids rarely selecting role-specific options. Missing roles never leave a decision without an eligible player. If everyone present is busy, the event waits until someone returns.
- **Voting:** each connected crew member at base votes via `TurnManager.cast_vote`. The most-voted option wins once everyone who can vote has voted. An accepted vote is locked (`already_decided` for another `actionId`); phone shows “Vote sent!” and the count. Disconnected phones do not block voting.
- **Ties:** hold a second vote only among tied options, with a new `eventId` (`<id>#<n>-tie`); a late first-round vote gets `event_closed`. A second tie is resolved randomly, with “It was a tie again, so luck decided!”. When a critical-event timer expires, the leading option wins, or the default option if nobody voted.
- **Rejections:** `choice_result` uses `event_closed`, `not_eligible` or `invalid_option`. Backend does not forward the result to the phone; the next `controller_view` updates it.
- **Backend failure:** `PhoneBridge` is disabled and the game continues on the main screen (with the `Phone (debug)` panel).

Test with `npm run dev` (backend on `:3000`), open `game/` in Godot and press F5, then visit `http://localhost:5173/controller/?room=<code>`. For full deployment, export to `dist/game/` and run `npm run docker:local`.

## Godot's responsibilities

Godot is **the authority on game rules** and the room's *host*:

1. Create the room, display code/QR and render the lobby.
2. Start the game.
3. Open events and send each controller its view.
4. **Validate** each `choose` (current event, valid option, eligible player, duplicates).
5. Resolve the event, apply consequences (oxygen, energy, health…) and advance.
6. Accept or reject each choice with `choice_result`.

Node only guarantees identity. A delivered message is not necessarily a valid game action.

## Architecture and connection

```text
Net (autoload, game/Scripts/net.gd)   ← only WebSocket client
  │ emits signals in Events
  ▼
Events (existing autoload)            ← signal bus
  ▲
  │ listeners
GameState / EventManager / Lobby UI   ← logic and screens
```

`Net` opens the socket, polls, parses JSON and emits signals. It exposes send methods (`create_room()`, `start_game()`, `send_view()`, `send_result()`…). Other game code does not know about the WebSocket. Add network signals to the existing `Events` autoload (`game/Scripts/events.gd`), which already has `mobile_client_connected`.

In web builds construct the URL from `location`; never hard-code an IP:

```gdscript
func _server_url() -> String:
    if OS.has_feature("web"):
        var proto: String = JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'")
        var host: String = JavaScriptBridge.eval("location.host")
        return "%s://%s/ws" % [proto, host]
    return "ws://localhost:3000/ws"
```

In the editor, use the local backend (`npm run dev`). `WebSocketPeer` is not signal-driven: call `poll()` every frame. Packets are `PackedByteArray`; decode with `get_string_from_utf8()`. `JSON.parse_string` returns `null` for invalid JSON; validate the type. All protocol IDs (`playerId`, `eventId`, `actionId`, `optionId`) are strings.

## Lobby and QR

1. Call `Net.connect_to_server()` on screen start; call `Net.create_room()` after `net_connected`.
2. On `room_created`, show code and QR.
3. Each `lobby_updated` is a full player list: redraw the whole lobby and dim players with `connected == false`.
4. Enable Start only when `players.size() >= 1` and every player has `role != null`. Otherwise Node may return `players_without_role` or `no_players`.
5. `Net.start_game()` yields the definitive `game_started` player list. **Store it** to determine roles present in the game.

QR content is `<LAN-address>/controller/?room=<code>`. Use `location.origin` only when it is not `localhost` or `127.0.0.1`; those addresses cannot be reached by phones. If the host opened `localhost`, warn and allow the LAN IP to be entered. Always display the code as a fallback.

## Events and choices

Each event should have an ID unique to that **occurrence**, not just the template: `storm-01#1`, `storm-01#2`. This lets Godot reject delayed choices for an old occurrence.

Build `eligible_players` from the `game_started` list, never a fixed list of four. If the assigned role is absent, use a documented deterministic substitute (e.g. `generalist` or first connected player) or make it a vote among present players. Send an informational/waiting view to ineligible players so they do not retain stale screens.

When opening an event, send `screen: "choice"` with the current `eventId`, title, prompt and options to eligible players; send `screen: "waiting"` to others. Each player may receive a different options array.

Recommended `choose` validation order:

1. If this `actionId` has a saved result, return the same result without repeating effects (search recent events too).
2. Reject a missing, closed or mismatched event with `event_closed`.
3. Reject an ineligible player with `not_eligible`.
4. Reject a nonexistent option with `invalid_option`.
5. Reject another action after that player already decided with `already_decided`.
6. Store the accepted decision/result, send `choice_result`, then try to resolve.

Remember accepted **and rejected** `actionId` results for idempotency. Always respond with `choice_result`; the backend validates the flow, although the phone does not receive it directly. The identity and role supplied by Node are trusted; never read them from phone data. `already_decided` with a different `actionId` means the player cast a second vote; the same ID is a retry and must be handled at step 1.

Resolve `individual` events when the assigned player decides. Resolve `vote` events when all **connected eligible players** have voted, choosing the most-voted option. Resolve ties with another round among tied options using a new `eventId`; if tied again, choose randomly. Close the event before applying effects. Apply consequences only during resolution, send `result` (or `waiting`) views, and emit game signals (`oxygen_level_changed`, etc.).

### Absent players

`lobby_updated` continues during the game and carries current `connected` flags. If a necessary player is absent, wait rather than resolving unilaterally. Give the host an explicit “Skip absent players” action to resolve with received decisions. On reconnect Node restores the last view; if the event resolved while the player was away, send the current view when `connected` becomes true.

### Ending and disconnects

Call `Net.finish_game()` when the mission ends. Show Godot results **before** calling it; afterwards the room no longer exists.

| Situation | Godot behavior |
|---|---|
| Host WebSocket disconnects | Node deletes the room and sends `room_closed` to controllers. Show a message and offer return to menu; do not reconnect to the same room. |
| Host tab reloads | Same as above: it is a new game. |
| Phone disconnects | `lobby_updated` marks `connected: false`; preserve role and decisions. |
| Backend restarts | Same as host disconnect. |

## Web export

- Web preset in `game/export_presets.cfg` exports to `../dist/game/index.html`. `thread_support=false`, so no COOP/COEP headers are needed.
- Godot 4 web requires a secure context (HTTPS or `localhost`); deployment uses HTTPS and `wss://`, derived from `location.protocol`. See [deployment](../deploy.md).
- The custom loading screen (`game/web/loading_shell.template.html`) animates a pixel-art rocket from Earth via the Moon to Mars. `tools/build_loading_shell.py` embeds images and fonts and generates `game/web/loading_shell.html`; run it after changing the template or images and before export. Preview using `index.html?fakeload=10` on localhost. The journey lasts at least about 3 seconds.
- Export to `dist/game/` before `npm run docker:local`.
- `JavaScriptBridge` and `OS.has_feature("web")` only work in web exports; guard them so the editor still works.
- Bundle all fonts, audio and images; the demo must not depend on Internet access. NASA API requests in `main.gd` must fail gracefully when offline.

## Testing checklist

1. Run `npm run dev` from the root (backend + controller). Note the backend port; the terminal logs all messages (`←` received, `→` sent).
2. Run the game from the editor, using `ws://localhost:<port>/ws`.
3. Open the controller on a phone (`http://<PC-IP>:5173/controller/?room=<code>`) or another browser tab.
4. A WebSocket client such as `npx wscat -c ws://localhost:<port>/ws` can send `join_room`, `select_role` and `choose` manually.

- [ ] `Net` polls every frame and centralizes socket access.
- [ ] Lobby is rendered from full `lobby_state`; disconnected players are distinct.
- [x] QR/link uses the LAN address, never `localhost`; code is also visible.
- [ ] Every event occurrence has a unique `eventId`.
- [ ] No event depends on an absent role.
- [ ] Repeated `actionId` returns same result without duplicate effects.
- [ ] A `choose` from an old event returns `event_closed`.
- [ ] Every `choose` gets a `choice_result`.
- [x] Tie → second vote → random resolution.
- [ ] After `net_disconnected`, offer return to menu.
