# NASA Hackathon 2026

A cooperative, room-based game for the NASA Hackathon 2026. Each session has a **main Godot screen** (exported to the web) and up to **four web controllers** (mobile phones), connected by a **Node backend** that keeps rooms separate. Nginx serves the application, and Docker Compose runs it on a local network or on the Internet.

> **Core rule:** Godot is the authority on the game; Node is the authority on who is connected, which room they belong to, and their role. Phones only send choices; they never decide consequences.

## How it fits together

```text
 Main screen (Godot, web) ──┐
                            ├── WebSocket /ws ──► Node backend ◄── Controllers (phones)
 Controllers (HTML/JS) ─────┘        (Nginx serves files, provides HTTPS and proxies requests)
```

## Project structure

| Folder | Contents | Status |
|---|---|---|
| [`game/`](game/) | Godot 4.7 project (GDScript) | In development |
| [`game_debug/`](game_debug/) | Separate Godot project for testing the connection with debug information | In development |
| [`backend/`](backend/) | Node server (Express + `ws`) | Implemented, with tests |
| [`controller/`](controller/) | Web controller (Vue 3 + Vite + Tailwind) | Implemented, with tests |
| [`landing/`](landing/) | Home page `/` (Vue + Vite + Tailwind): what the game is and how to play | Implemented |
| [`deploy/`](deploy/) | Nginx application image and local HTTPS proxy | Implemented |
| [`scripts/`](scripts/) | `npm run dev` (backend + controller) | Development tools |
| `dist/game/` | Godot web export | Generated on export and committed; re-export and commit it after changing `game/` |
| `dist/game_debug/` | `game_debug` web export | Generated on export and committed |
| `dist/controller/` | Controller build | Generated with `npm run build`; not committed |
| [`docs/`](docs/) | Documentation in Spanish and English | See below |
| `compose.yaml` | Main Internet deployment with Coolify | Implemented |
| `compose.local.yaml`, `compose.dev.yaml` | Local deployment (game or debug screen) | Implemented |

## Documentation

The [English documentation index](docs/en/README.md) lists the available guides. Spanish originals remain in [`docs/`](docs/README.md).

| Document | Audience | Contents |
|---|---|---|
| [`docs/en/protocol.md`](docs/en/protocol.md) | **Everyone** | Message contract, errors, sequences and acceptance criteria. **Source of truth**: update it first. |
| [`docs/en/game-design.md`](docs/en/game-design.md) | **Everyone** | Game rules: Sol loop, roles, resources, objectives, NASA APIs and **open decisions**. |
| [`docs/en/event-catalog.md`](docs/en/event-catalog.md) | Design / Godot | Events, options, effects and NASA sources. Numbers come from `game/Data/events.json`. |
| [`docs/en/godot/architecture.md`](docs/en/godot/architecture.md) | Godot team | Managers, Sol state machine, models and `events.json` format. |
| [`docs/en/godot/networking.md`](docs/en/godot/networking.md) | Godot team | Implementing the contract: `Net` autoload, lobby, QR, events, idempotency and voting. |
| [`docs/en/controller.md`](docs/en/controller.md) | Web controller | Vue architecture, role routes (NFC), states, session recovery, styling and deployment. |
| [`docs/en/backend.md`](docs/en/backend.md) | Backend | Technologies, structure, room model, reconnection and MVP limits. |
| [`docs/en/deploy.md`](docs/en/deploy.md) | Deployment | Coolify Internet deployment, local deployment and common issues. |
| [`docs/en/overview.md`](docs/en/overview.md) | Everyone | Summary of the implemented game. |
| [`docs/en/crew-availability.md`](docs/en/crew-availability.md) | Game design / Godot | Crew task durations and empty-base rules. |

## Get started

Requirement: Node.js ≥ 22.

### Run the full development setup

```bash
npm install      # also installs backend/ and controller/ dependencies
npm run dev
```

This starts the **backend** and **controller** (Vite). The host creates the room in Godot; then open the controller on a phone on the same Wi-Fi at `http://<PC-IP>:5173/controller/?room=<code>`.

The same terminal shows **all raw messages** passing through the backend (`←` received, `→` sent, and the connection involved):

```text
[backend]    ← host K7MP     {"type":"start_game"}
[backend]    → K7MP/p1       {"type":"game_started","players":[...]}
```

Disable message logging with `LOG_MESSAGES=0 npm run dev`.

Other commands from the repository root:

```bash
npm test              # backend and controller tests
npm run build         # generates dist/controller/
```

Ports are selected automatically. If port 3000 is occupied or reserved (Hyper-V/WSL may reserve it on Windows), the backend selects another port and the controller is configured to use it. If the phone cannot load the page, check that it is on the same network and that the Windows firewall allows Node on private networks.

### Run each part separately

```bash
cd backend && npm run dev       # :3000 (PORT=<other> to change it, LOG_MESSAGES=1 to log messages)
cd controller && npm run dev    # :5173/controller/ (BACKEND_PORT=<backend port>)
```

### Godot

Open `game/project.godot` with Godot 4.7. To export, choose **Project → Export → Web** (generates `dist/game/index.html`).

### Docker deployment

The main deployment is **on the Internet with Coolify**: create a *Docker Compose* resource using `compose.yaml` and configure the domain on the `web` service. Coolify provides HTTPS (Let's Encrypt).

For local HTTPS with a self-signed certificate:

```bash
npm run docker:local   # the game (dist/game)
npm run docker:dev     # the debug screen (dist/game_debug), with message logging
```

Locally, open the screen using the **LAN IP** (`https://192.168.1.50/game/`), not `localhost`; browsers will warn about the certificate the first time. See [`docs/en/deploy.md`](docs/en/deploy.md).

## Routes

| Route | Serves |
|---|---|
| `/` | Create a game or join with a code |
| `/game/` | Main screen (Godot) |
| `/controller/` · `/controller/?room=K7MP` | Web controller (the QR code preloads the room code) |
| `/controller/engineer` · `/biologist` · `/doctor` · `/generalist` | Controller opening directly to a role (physical NFC board) |
| `/ws` | WebSocket |
| `/api/health` | Backend health check |

## First milestone

A real button on a phone changes text in Godot exported to the web. Then verify the acceptance criteria in [`docs/en/protocol.md`](docs/en/protocol.md#acceptance-criteria).

## Conventions

- Code and identifiers are in English. Game and controller text uses simple English for children aged 7–12. Documentation is available in Spanish and English.
- Commits use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): description`. Example: `feat(backend): create in-memory rooms`.
- Any message-contract change must be agreed in `docs/protocol.md` first.
