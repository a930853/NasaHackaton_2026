# Red Planet Survivors

**A cooperative Mars survival game built for NASA Hackathon 2026.**

Players work together to keep a Mars base alive for 20 Sols. One shared Godot game screen presents the mission, while up to four players use their phones to join a room, choose roles and vote on decisions.

[![Apache-2.0 License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-%E2%89%A522-green.svg)](https://nodejs.org/)

> **Project:** Red Planet Survivors<br>
> **Event:** NASA Hackathon 2026<br>
> **Status:** Active development

This is an independent hackathon project and is not an official NASA product or affiliated with or endorsed by NASA.

### Test the game

- The game is currently running on a member's server -> https://red-planet-survivors.karu.es/

## At a glance

- **Cooperative gameplay:** discuss trade-offs and protect the crew, oxygen, energy and base integrity.
- **Flexible player count:** play solo or with 1–4 mobile controllers.
- **Real science inspiration:** events draw on NASA missions and planetary science.
- **Room-based multiplayer:** a Node.js backend keeps game sessions and player identities separate.
- **Web deployment:** play in a browser; Docker Compose and Nginx support local demos and Internet hosting.
- **Offline-ready demo:** game assets are bundled locally, and NASA data features have fallbacks.

## How it works

```text
Godot game screen ─────────┐
                           ├── WebSocket (/ws) ── Node.js backend
Mobile web controllers ───┘                         │
                                        Nginx serves the web apps
```

**Authority is deliberately split:** Godot owns game rules, event validation and consequences. Node owns rooms, connections and player roles. A phone sends only an `optionId`; it never calculates game outcomes. Player identity is derived from the registered connection, not trusted from a phone-supplied `playerId`.

## Technology

| Area | Technologies |
|---|---|
| Game | Godot 4.7, GDScript |
| Mobile controller | Vue 3, Vite, Tailwind CSS 4 |
| Landing page | Vue 3, Vite, Tailwind CSS 4 |
| Backend | Node.js 22+, Express, `ws` |
| Hosting | Nginx, Docker Compose; Coolify for the primary Internet deployment |

## Get started

### Requirements

- Node.js **22 or later**
- npm
- Godot 4.7 to run or export the game screen
- Docker Compose for containerized deployment

### Run the development environment

From the repository root:

```bash
npm install
npm run dev
```

This starts the backend, mobile controller and landing page. Open the URL printed in the terminal (normally `http://localhost:5173/`). The host creates a room in Godot; players can then join from phones on the same Wi-Fi using the displayed room code.

The development server serves the most recent Godot export at `/game/`. If port 3000 is unavailable, the backend selects another free port and the web apps are configured to use it.

```bash
npm test       # backend and controller tests
npm run build  # build controller and landing page
```

### Run the game in Godot

Open `game/project.godot` in Godot 4.7. To build the browser version, select **Project → Export → Web** and export to `dist/game/`.

### Run with Docker

Export the Godot project to web before building the image.

```bash
npm run docker:local  # local HTTPS deployment serving dist/game/
npm run docker:dev    # local HTTPS deployment serving dist/game_debug/
```

The local HTTPS certificate is self-signed, so each browser will ask you to accept it on first use. Open the game and controllers using the host PC's **LAN IP address**, not `localhost`. For Internet deployment with Coolify, configure `compose.yaml` and the domain on the `web` service.

## Project layout

```text
game/                  Godot game
game_debug/            Godot connection-testing project
backend/               Node.js room/session server
controller/            Mobile web controller
landing/               Landing page and join/create entry point
deploy/                Nginx and TLS Docker configuration
scripts/               Root development launcher
dist/game/             Committed Godot web export
dist/game_debug/       Committed debug-game web export
docs/                  Spanish documentation
docs/en/               English documentation
compose*.yaml          Docker Compose deployment configurations
```

## Documentation

- **English:** [Documentation index](docs/en/README.md)
- **Español:** [Índice de documentación](docs/README.md)
- [Message protocol](docs/en/protocol.md) — shared contract and source of truth for network changes
- [Game design](docs/en/game-design.md) · [Event catalog](docs/en/event-catalog.md)
- [Godot architecture](docs/en/godot/architecture.md) · [Godot networking](docs/en/godot/networking.md)
- [Controller guide](docs/en/controller.md) · [Backend guide](docs/en/backend.md)
- [Deployment guide](docs/en/deploy.md)

## License and credits

This project is distributed under the **Apache License 2.0**; see [`LICENSE`](LICENSE). Third-party fonts, images and other assets may have their own terms and attributions. For example, the landing-page Mars image is credited to **ESA/DLR/FU Berlin**, processed by **J. Cowart**. Please retain applicable third-party notices when using or redistributing those materials.

NASA names and mission references are used to identify scientific sources and inspirations; they do not imply NASA endorsement.
