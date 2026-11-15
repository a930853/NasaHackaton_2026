# Godot Networking: Backend and Phones

How to connect `game/` to the backend using the [message protocol](../protocol.md). Other game systems (managers, state machine and `events.json`) are described in [architecture.md](architecture.md).

## Implementation status in `game/`

The real game is connected to the backend and web controller:

| Component | File | Purpose |
|---|---|---|
| `Net` autoload | `game/Scripts/net.gd` | Only WebSocket client. Emits network signals through `Events`; exposes `create_room()`, `start_game()`, `send_view()`, `send_result()`, `finish_game()`. |
| `PhoneBridge` autoload | `game/Scripts/phone_bridge.gd` | Connects `TurnManager` to phones: sends each player's `controller_view`, **validates** each `choose` (current event, player, option, duplicate `actionId`) and always responds with `choice_result`. |
| Lobby | `game/Scripts/main_menu.gd` (`Lobby` node in `Main_menu.tscn`) | “Start Game” offers **Play solo** or **Play multiplayer**. Multiplayer connects, creates a room and shows code, controller address and players/roles. “Start expedition” requires ≥1 player and roles for all. “Play solo instead” and “Back” leave the lobby. A missing server is detected after 4 s. |
| Signals | `game/Scripts/events.gd` | `net_connected`, `net_disconnected`, `net_connection_failed`, `room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `player_continue_received`, `room_closed`, `net_error`. |

The lobby uses the game's visual style: blue button frame, role-color helmet cards (four slots, dimmed empty slots and Commander marked), highlighted room code and QR on a white panel with blue frame.

Flow: menu → lobby (room created, phones join/select roles) → `start_game` → intro → game. For each event, `TurnManager` emits `event_presented`; `PhoneBridge` sends **all options** to each phone (`TurnManager.controller_view_for(role)`, with `detail` for costs and `disabled`/`reason` for busy roles). After resolution all phones receive a `result` view. Returning to the menu closes the room with `finish_game`.

Implementation decisions:

- **Server URL:** in web builds, use `location` (never a hard-coded IP). In the editor, `ws://localhost:3000/ws`; override with `--ws-url=ws://localhost:3100/ws` or `NASA_WS_URL`.
- **Displayed controller address:** web uses `location.origin`; editor uses `http://localhost:5173` (Vite). The lobby warns if it contains `localhost`.
- **QR:** multiplayer lobby displays it beside instructions using `Net.controller_url(code)`. `game/Scripts/qr_code.gd` generates QR in GDScript without dependencies (byte mode, correction M, versions 1–10, up to 213 bytes). Keep the text code and URL visible as a fallback; the landing page also allows manual entry.
- **Everyone votes on every option:** each phone receives all options; role-owned options are prefixed with the role and occupy that character. This avoids rarely selecting role-specific options. Missing roles never leave a decision without an eligible player. If everyone present is busy, the event waits until someone returns.
- **Voting:** each connected crew member at base votes via `TurnManager.cast_vote`. The most-voted option wins once everyone who can vote has voted. An accepted vote is locked (`already_decided` for another `actionId`); phone shows “Vote sent!” and the count. Disconnected phones do not block voting.
- **Ties:** hold a second vote only among tied options, with a new `eventId` (`<id>#<n>-tie`); a late first-round vote gets `event_closed`. A second tie is decided by the Commander's vote (the first player who joined), with “It was a tie again, so the Commander's vote decided!”. When a critical-event timer expires, the leading option wins, or the default option if nobody voted.
- **Rejections:** `choice_result` uses `event_closed`, `not_eligible`, `invalid_option` or `already_decided`. Backend does not forward the result to the phone; the next `controller_view` updates it.
- **Backend failure:** `PhoneBridge` is disabled and the game continues on the main screen as in solo mode: options are chosen with the mouse.

Test with `npm run dev` (the terminal prints the ports in use: the backend tries 3000 and falls back to a free port, in which case start the game with `--ws-url`), open `game/` in Godot and press F5, then visit `http://localhost:5173/controller/?room=<code>`. For full deployment, export to `dist/game/` and run `npm run docker:local`.

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

`Net` opens the socket, polls, parses JSON and emits signals. It exposes send methods (`create_room()`, `start_game()`, `send_view()`, `send_result()`…). Other game code does not know about the WebSocket. All network signals already live in the `Events` autoload (`game/Scripts/events.gd`, listed above). Event logic (`TurnManager`) does not depend on `Net`: `PhoneBridge` listens to its signals and the network signals and calls `Net.send_view(...)` / `Net.send_result(...)`.

In web builds the URL is built from `location`; never hard-code an IP. This is `Net.default_url()` (abridged):

```gdscript
func default_url() -> String:
    if OS.has_feature("web"):
        var proto: String = str(JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'"))
        var host: String = str(JavaScriptBridge.eval("location.host"))
        return "%s://%s/ws" % [proto, host]
    # Outside the browser: --ws-url=... argument, NASA_WS_URL variable, or the local default.
    ...
    return "ws://localhost:3000/ws"
```

In the editor, use the local backend (`npm run dev`); if it did not get port 3000, pass `--ws-url=ws://localhost:<port>/ws` (or `NASA_WS_URL`). `WebSocketPeer` is not signal-driven: call `poll()` every frame. Packets are `PackedByteArray`; decode with `get_string_from_utf8()`. `JSON.parse_string` returns `null` for invalid JSON; validate the type. All protocol IDs (`playerId`, `eventId`, `actionId`, `optionId`) are strings.

## Lobby and QR

1. Call `Net.connect_to_server()` on screen start; call `Net.create_room()` after `net_connected`.
2. On `room_created`, show code and QR.
3. Each `lobby_updated` is a full player list: redraw the whole lobby and dim players with `connected == false`.
4. Enable Start only when `players.size() >= 1` and every player has `role != null`. Otherwise Node may return `players_without_role` or `no_players`.
5. `Net.start_game()` yields the definitive `game_started` player list. **Store it** to determine roles present in the game.

QR content is `<LAN-address>/controller/?room=<code>`, from `Net.controller_url(code)`. The base is `location.origin` (in the editor, `http://localhost:5173`). If it contains `localhost` or `127.0.0.1` (`Net.controller_url_is_local()`), the lobby warns that phones cannot reach it: open the game through the LAN address instead (e.g. `http://192.168.1.50`). There is no field to type the IP by hand. The code is always displayed as a fallback.

## Events and choices

Events come from `game/Data/events.json` and are run by `TurnManager` (see [architecture.md](architecture.md)). Every event is decided **by vote**; there are no `individual` events and no per-event `eligible_players` list.

Each event ID is unique to that **occurrence**, not just the template: `TurnManager` builds it from the template and a global counter (`<id>#<n>`, e.g. `storm-01#1`, `storm-01#2`; the tie-break adds `-tie`). A delayed choice for an old occurrence is rejected with `event_closed`.

With 1–4 players no event can be left without someone to decide, so **everyone votes on every option**. `TurnManager.controller_view_for(role)` sends each phone **all** the event's options; role-owned options are prefixed with the role name (`(Engineer) …`) but anyone can vote for them, whether or not that role is in the game. If the owning role is away from the base (or the option needs the whole crew at the base), the option arrives with `disabled` and `reason`. Voters are the **connected** roles at the base with at least one free option (`TurnManager.voters()`); players who cannot vote receive a `waiting` view (“You are busy!”, “Read the story!”, “Vote sent!”…) so they never keep a stale screen.

`choose` validation order (`PhoneBridge._on_choice` in `game/Scripts/phone_bridge.gd`; event checks in `TurnManager.choice_reject_reason`):

1. If this `actionId` has a saved result, return the same result without repeating effects.
2. Reject a player who is not in the game with `not_eligible`.
3. Reject a missing, closed or mismatched event (or one still being read on the main screen) with `event_closed`.
4. Reject a role that is away from the base with `not_eligible`.
5. Reject another action after that role already voted with `already_decided`.
6. Reject a nonexistent or disabled option (or one outside the tie-break) with `invalid_option`.
7. Store the accepted result, send `choice_result`, then cast the vote (`TurnManager.cast_vote`).

Accepted **and rejected** `actionId` results are remembered for idempotency. Every `choose` gets a `choice_result`; the backend validates the flow, although the phone does not receive it directly. After a rejection, the phone is sent the current view. The identity and role supplied by Node are trusted; they are never read from phone data. `already_decided` with a different `actionId` means the player cast a second vote; the same ID is a retry and is handled at step 1.

When the last voter votes (`TurnManager._try_resolve_votes`), the most-voted option wins. Ties go to another round among the tied options with a new `eventId`; if tied again, the Commander's vote decides (or the first tied option if the Commander voted for none of them). When a critical-event timer expires, the leading option wins (or the default option if nobody voted). The event closes before effects are applied; consequences are applied only during resolution. Every player receives a `result` view with `canContinue: true`; once all connected players confirm (`continue`), the game moves to the next Sol (the host can also advance from the main screen). Game signals (`oxygen_level_changed`, etc.) update the UI.

### Absent players

`lobby_updated` continues during the game and carries current `connected` flags. A disconnected player **does not block** the event: they stop counting as a voter and the event resolves with the votes of connected players (if nobody can vote, the event waits). There is no “skip absent players” button because none is needed. On reconnect Node restores the last view, and `PhoneBridge` also sends the current view when `connected` becomes true (in case the event resolved while the player was away).

### Ending and disconnects

When the mission ends, phones receive a `result` view with `canContinue: false` and the score. `Net.finish_game()` is called on returning to the menu: controllers receive `room_closed` (`game_finished`) and the room no longer exists.

| Situation | Godot behavior |
|---|---|
| Host WebSocket disconnects | Node deletes the room and sends `room_closed` to controllers. In the lobby, a message offers “Back” or “Play solo instead”; during a game, `PhoneBridge` is disabled and play continues on the main screen. The game does not reconnect to the same room. |
| Host tab reloads | Same as above: it is a new game. |
| Phone disconnects | `lobby_updated` marks `connected: false`; role and vote are kept, and the player stops counting as a voter. |
| Backend restarts | Same as host disconnect. |

## Web export

- Web preset in `game/export_presets.cfg` exports to `../dist/game/index.html`. `thread_support=false`, so no COOP/COEP headers are needed.
- Godot 4 web requires a secure context (HTTPS or `localhost`); deployment uses HTTPS and `wss://`, derived from `location.protocol`. See [deployment](../deploy.md).
- The custom loading screen (`game/web/loading_shell.template.html`) animates a pixel-art rocket from Earth via the Moon to Mars. `tools/build_loading_shell.py` embeds images and fonts and generates `game/web/loading_shell.html`; run it after changing the template or images and before export. Preview using `index.html?fakeload=10` on localhost. The journey lasts at least about 3 seconds.
- Export to `dist/game/` before `npm run docker:local`.
- `JavaScriptBridge` and `OS.has_feature("web")` only work in web exports; guard them so the editor still works.
- Bundle all fonts, audio and images; the demo must not depend on Internet access. NASA API requests in `nasa_api.gd` (started by `main.gd`) and the DONKI request in `turn_manager.gd` must fail gracefully when offline.

## Testing checklist

1. Run `npm run dev` from the root (backend + controller + landing). Note the backend port it prints; the terminal logs all messages (`←` received, `→` sent).
2. Run the game from the editor, using `ws://localhost:<port>/ws` (3000 by default; otherwise pass `--ws-url`).
3. Open the controller on a phone (`http://<PC-IP>:5173/controller/?room=<code>`) or another browser tab.
4. A WebSocket client such as `npx wscat -c ws://localhost:<port>/ws` can send `join_room`, `select_role` and `choose` manually.

Implementation status in `game/`:

- [x] `Net` polls every frame and centralizes socket access.
- [x] Lobby is rendered from full `lobby_state`; disconnected players are distinct.
- [x] QR/link uses the page address, with a warning if it is `localhost`; code is also visible.
- [x] Every event occurrence has a unique `eventId` (`<id>#<n>`, `-tie` for the tie-break).
- [x] No event depends on an absent role (everyone votes on every option).
- [x] Repeated `actionId` returns same result without duplicate effects.
- [x] A `choose` from an old event returns `event_closed`.
- [x] Every `choose` gets a `choice_result`.
- [x] Tie → second vote among tied options → if still tied, the Commander's vote decides.
- [x] After `net_disconnected`: the lobby offers going back or playing solo; during a game play continues on the main screen.
