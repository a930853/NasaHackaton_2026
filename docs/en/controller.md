# Web Controller

The **Vue 3 + Vite + Tailwind CSS 4** (JavaScript) app used by each player on a phone. It talks to the backend over `/ws` using the [message protocol](protocol.md). The controller **only sends choices**; it does not know game rules or resources.

## Run

From the repository root, `npm install && npm run dev` starts the backend, controller and landing with backend message logging enabled (see the [root README](../../README.md#run-the-development-environment)). A Godot host must create the room.

Or run separately:

```bash
# 1. Backend
cd backend && npm install && npm run dev        # :3000

# 2. Controller
cd controller && npm install && npm run dev    # http://localhost:5173/controller/
npm test                                        # store tests against the real backend
npm run build                                   # generates ../dist/controller/
```

- `npm run dev` listens on the LAN too: open `http://<PC-IP>:5173/controller/` on a phone.
- Vite proxies `/ws` to the backend, so the code always uses `location.host`, as it does behind Nginx.
- **Windows and port 3000:** Hyper-V/WSL may reserve it (`listen EACCES`). Check `netsh interface ipv4 show excludedportrange protocol=tcp`; use `PORT=8787 npm run dev` in `backend/` and `BACKEND_PORT=8787 npm run dev` in `controller/`.
- Tests import `backend/src/server.js`, so dependencies must also be installed in `backend/`.

## Routes and roles

The app is served beneath `/controller/` (Vite and router base).

| Route | Use |
|---|---|
| `/controller/` | Normal entry: asks for room code and name, then offers role selection. |
| `/controller/?room=K7MP` | Same, with code prefilled (QR destination). |
| `/controller/engineer` · `/biologist` · `/doctor` · `/generalist` | **Direct role entry** (physical NFC board). Asks for code/name if no `?room=` and reserves that role on join. Commander is an extra ability granted to the first player. |
| `/controller/<role>?room=K7MP` | Direct entry with room and role. |

The route expresses player **intent**; the backend confirms the actual role through `lobby_state`.

- In the lobby, opening `/controller/<role>` by button or NFC sends `select_role`. If occupied, return to `/controller/` with a notice.
- Once the game starts, roles are fixed and the route is corrected to the confirmed role.
- A player restoring a session from `/controller/` is redirected to their role route.

**NFC board:** each tag stores the role URL without a room, e.g. `http://192.168.1.50/controller/engineer`. The player scans it, enters the code shown on screen and their name, and joins directly as that role. Nginx must serve `index.html` for all `/controller/` routes.

## Structure and architecture

```text
controller/
  index.html
  vite.config.js           base /controller/, output ../dist/controller, /ws proxy, Tailwind
  src/
    main.js                creates/injects session and connects after URL resolution
    router.js              home + one route per role (meta.role)
    App.vue                <RouterView /> only
    roles.js               role data and Commander ability
    messages.js            text for errors, rejections and room closure
    styles.css             Tailwind theme and shared classes
    net/socket.js          WebSocket: URL from location, backoff reconnect
    stores/session.js      reactive session state and actions (join, selectRole, choose…)
    views/
      ControllerView.vue   selects screen from session state and route
      EnterView.vue        code + name
      RolePicker.vue       lobby role selection
    components/
      ChoiceView.vue       question and options (`controller_view` "choice")
      StatusCard.vue       waiting, registered choice, result, closed room
      CrewList.vue         crew (name, role, connection)
      DevicePlate.vue      identity plate: role-colored helmet, name and room code
    assets/                helmet, Mars photo and screw (copied from game/Images)
  test/session.test.js     store tests against the real backend
```

- **Only `net/socket.js` accesses the WebSocket.** Only `stores/session.js` interprets messages.
- Views read `session.state` and call actions; they do not construct messages.
- **Godot dictates game screens** through `controller_view`; the controller owns no questions or options.

## Session state

`session.state` is reactive:

| Field | Values |
|---|---|
| `connection` | `connecting` · `online` · `offline` (reconnecting) · `replaced` (another device took the session) |
| `phase` | `connecting` · `enter` · `joining` · `lobby` · `playing` · `closed` |
| `code`, `playerId`, `name`, `role`, `commander` | Identity confirmed by backend |
| `players`, `roomStatus` | Latest `lobby_state` |
| `view` | Latest `controller_view` |
| `choice` | `{ status: idle · sending · registered · rejected, eventId, optionId, reason }` |
| `error` | `{ code, requestType, seq }`; `seq` changes on each error |
| `closedReason` | `room_closed` reason |

`ControllerView.vue` renders connection replacement as “Opened somewhere else” with “Use this device”; connecting/joining as “Connecting…”; entry, closed room, role picker or saved role as appropriate. During a game it displays “Lift-off!” before the first view, `ChoiceView` for choices, the result plus “Continue”, or a waiting screen.

## Navigation, recovery and choices

- On `joined`, save code, `resumeToken` and `playerId` in `localStorage` (`nasa.controller.session`). Reload/reconnect sends `resume_player`.
- If `?room=` differs from the stored code, discard the saved session (it is another game).
- If `resume_player` fails (`invalid_token`, `room_not_found`), clear saved data and return to entry.
- Pressing an option creates an `actionId` (`<playerId>-<random>`, using `crypto.getRandomValues`, which works over HTTP) and saves it as **pending**. Disable buttons and show “Sending…”.
- If the page reloads or the network drops before `choice_result`, session recovery restores the same view and **resends the same `actionId`**. Godot responds consistently without repeating effects.
- The controller does not receive `choice_result`; it waits for Godot's next `controller_view` (result, waiting or a new question).
- On a `result` view with `canContinue: true`, **Continue** sends a confirmation. The game advances when all connected controllers confirm or the host presses the main-screen button.
- A view that is not for the pending choice clears it.
- `room_closed` clears credentials. “Back to home” opens a new connection (the old one remains associated with the closed room).
- If another device resumes the same session, Node closes this connection with code `4000`; do not reconnect automatically. Offer “Use this device”.

“Back to home” is available before joining; “Keep my job” when picking a role already held; and “Change job” / “Leave the room” once a role is saved. `leave_room` is allowed only in the lobby; Node deletes the player and frees the role. Leaving is not available after the game starts.

## Styling

The controller looks like a **game-cabin device** over the Mars menu image: `device` casing with screws cropped from `hud_frame.png`, role-color identity plate (`DevicePlate.vue`), beveled screens (`screen`) and pressable keys (`key`; `key-quiet` for secondary actions, `key-off` for disabled options).

Tailwind 4 with `@tailwindcss/vite`. The `@theme` in `styles.css` defines the palette (`hull`, `ink`, `screen`, `glass`, `key-red/cyan/orange/purple`…) and fonts: Sixtyfour (`font-display`, short text only) and Chakra Petch (`font-sans`). `roleStyle()` in `roles.js` sets CSS variable `--role-color`. Images are in `src/assets/` (helmet, Mars photo, screw), copied from `game/Images`.

Fonts use `@fontsource`. **Nothing is downloaded from the Internet**; the LAN demo must work offline.

## Deployment

`npm run build` generates untracked `dist/controller/`. The Docker `web` image (`deploy/web.Dockerfile`) builds it itself, so there is no need to build it before starting Compose. Nginx (`deploy/nginx/default.conf`; the `web` image copies `dist/controller/` into `/srv/www`) serves the app at `/controller/` with `index.html` fallback for direct role routes (NFC and page reload):

```nginx
# deploy/nginx/default.conf (excerpt)
root /srv/www;

# Controller (Vue). Role routes (/controller/engineer…) are not files:
# index.html is served and the controller's router decides.
location /controller/ {
    try_files $uri $uri/ /controller/index.html;
}
```

## Still to test

- Test on real phones (iOS Safari and Android Chrome), including screen lock and network changes.
- Add a final-result screen if Godot sends more `view` fields (e.g. resources); update the protocol first.
