# Deployment

The primary deployment is **on the Internet with Coolify** (a VPS with a domain). Locally, the same `compose.yaml` plus an override can deploy either **the game** or **the debug screen**.

| | Command | What `/game/` serves | HTTPS |
|---|---|---|---|
| **Internet** (primary) | Coolify with `compose.yaml` | `dist/game` (the game) | Coolify's Traefik, Let's Encrypt |
| Local | `npm run docker:local` | `dist/game` (the game) | `tls` service, self-signed certificate |
| Local development | `npm run docker:dev` | `dist/game_debug` (debug) + message log | `tls` service, self-signed certificate |

Before deploying, **export the Godot project to web**: open `game/` or `game_debug/` in Godot → **Project → Export → Web**. Both exports are committed in `dist/`. If one is missing, the image build fails with an explanation.

For development, `npm run dev` (without Docker) is more convenient and reloads immediately.

## Architecture

Godot 4 **requires a secure context** (HTTPS or `localhost`) to run in a browser, so an HTTPS proxy is always needed. The app is the same in both environments; only the HTTPS provider changes:

```text
Internet:  browser ──https──> Traefik (Coolify) ──http──> web (Nginx :80) ──> backend (:3000)
Local:     browser ──https──> tls (Nginx :443)   ──http──> web (Nginx :80) ──> backend (:3000)
```

- **`web`** always serves HTTP on port 80: landing page, controller, Godot, and `/ws` and `/api` proxies to the backend. It does not handle certificates.
- **`tls`** (local only) acts like Coolify's Traefik: it encrypts traffic with a self-signed certificate and forwards everything, including WebSocket, to `web`.

Everything uses the same origin, so the screen and phones build the WebSocket URL from `location` (`wss://<host>/ws`); no IP addresses or domains are hard-coded.

## Internet deployment with Coolify

1. **DNS:** point an `A` record (e.g. `mars.example.com`) to the VPS IP.
2. In Coolify, choose **+ New → Resource → Public/Private Repository** and select this repository and the `main` branch.
3. Set **Build Pack: Docker Compose** and **Docker Compose Location** to `/compose.yaml`.
4. Configure the domain with `https://` on the **`web`** service, e.g. `https://mars.example.com`. Leave `backend` without a domain; it is reachable only through `web`.
5. **Deploy.** The first build takes longer because it compiles the controller inside the image; Traefik then requests the certificate.

The screen is at `https://mars.example.com/game/` and phones use `https://mars.example.com/` with the room code, **from any network**. Browsers do not warn because the certificate is valid.

`compose.yaml` publishes no ports (the VPS ports 80 and 443 belong to Traefik) and both services have health checks.

Important:

- **Coolify builds from Git:** it serves the committed `dist/game/`. After changing `game/`, export and commit `dist/game/` before redeploying.
- **Rooms are in memory:** redeploying or restarting the backend ends current games. Avoid doing so during a demo.
- **The service is Internet-facing:** anyone with the address can create a room. A room code is not a credential, but it is required to join a room. The backend rejects messages larger than 64 KB.

## Local deployment

```bash
npm run docker:local   # the game
npm run docker:dev     # debug screen; view messages with `docker compose logs -f backend`
```

| Client | Address |
|---|---|
| Screen / projector | `https://<PC-LAN-IP>/game/` |
| Phones on the same Wi-Fi | `https://<PC-LAN-IP>/` with the code, or `https://<PC-LAN-IP>/controller/?room=<code>` |

Open the screen using the **LAN IP**, not `localhost`: when opened using `localhost`, the address displayed for controllers will not be usable from phones.

The certificate is **self-signed**. The `tls` service creates it on first startup and stores it in the `certs` volume, so it remains the same across restarts. **Each browser displays a warning the first time** (“connection is not private”); proceed through *Advanced → Continue*, including on phones. To avoid the warning, put your own `cert.pem` and `key.pem` (e.g. from [mkcert](https://github.com/FiloSottile/mkcert)) in that volume.

The Godot **desktop editor** cannot connect to this deployment because it rejects the self-signed certificate. Use `npm run dev` from the editor.

## Components

```text
compose.yaml                 Internet (Coolify): backend + web, no published ports, health checks
compose.local.yaml           Local: adds tls on ports 80 and 443
compose.dev.yaml              Local development: GAME_EXPORT=game_debug and LOG_MESSAGES=1
deploy/web.Dockerfile         Builds controller and landing (Vite) and copies dist/<GAME_EXPORT>/
deploy/nginx/default.conf     Application Nginx (HTTP): routes and /ws and /api proxies
deploy/tls/                   Local HTTPS proxy: Dockerfile, nginx.conf and 15-cert.sh
.dockerignore                 Excludes node_modules, .godot, Godot projects, etc.
```

| Route | Purpose |
|---|---|
| `/` | Landing page (built from `landing/`) |
| `/game/` | Godot export, without caching (exports reuse file names) |
| `/controller/…` | Controller; role routes fall back to `index.html` |
| `/ws` | WebSocket proxy to the backend (1-hour timeout) |
| `/api/` | HTTP proxy to the backend |

The `.wasm` and JavaScript files are served compressed (Godot's `.wasm` shrinks from about 39 MB to 12 MB).

## Common issues

| Symptom | Cause |
|---|---|
| “Secure Context - Check web server configuration (use HTTPS)” | `/game/` was opened over `http://`. Use `https://`. |
| “Room does not exist” | The controller is connected to another backend (e.g. `npm run dev` is also running on `:5173`). Open the controller from the same address as the screen. |
| Local port 80 or 443 is occupied | Run `HTTP_PORT=8080 HTTPS_PORT=8443 npm run docker:local` and open `https://<IP>:8443/`. |
| Phone cannot load the local site | Use the same Wi-Fi as the PC and allow Docker through the Windows firewall on ports 80 and 443. |
| Coolify shows “Bad Gateway” or no certificate | Configure the domain on `web` (not `backend`) and make sure DNS points to the VPS. |
