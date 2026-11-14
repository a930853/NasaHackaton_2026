# NasaHackaton 2026

Juego cooperativo por salas para el NASA Hackathon 2026. Una **pantalla principal en Godot** (exportada a web) y **hasta cuatro mandos web** (móviles) por partida, conectados por un **backend Node** que mantiene las salas separadas. Se sirve con **Nginx** y se levanta con **Docker Compose** en la red local.

> **Regla fundamental:** Godot es la autoridad sobre el juego; Node, sobre quién está conectado, en qué sala y con qué rol. El móvil solo envía elecciones; nunca decide consecuencias.

## Cómo encaja todo

```text
 Pantalla (Godot, web) ──┐
                         ├── WebSocket /ws ──► Backend Node ◄── Mandos (móviles)
 Mandos (HTML/JS) ───────┘        (Nginx hace de proxy y sirve los archivos)
```

## Estructura

| Carpeta | Contenido | Estado |
|---|---|---|
| [`game/`](game/) | Proyecto Godot 4.7 (GDScript) | En desarrollo |
| [`backend/`](backend/) | Servidor Node (Express + `ws`) | Implementado, con tests |
| [`controller/`](controller/) | Mando web (Vue 3 + Vite + Tailwind) | Implementado, con tests |
| `landing/` | Página de inicio `/` | Pendiente |
| `deploy/` | Configuración de Nginx | Pendiente |
| [`scripts/`](scripts/) | `npm run dev` y simulador de Godot | Herramientas de desarrollo |
| `dist/game/` | Exportación web de Godot | Se genera al exportar |
| `dist/controller/` | Build del mando | Se genera con `npm run build` (no se versiona) |
| [`docs/`](docs/) | Documentación | Ver abajo |
| `compose.yaml` | Nginx + backend | Pendiente |

## Documentación

| Documento | Para quién | Qué cuenta |
|---|---|---|
| [`docs/protocol.md`](docs/protocol.md) | **Todos** | Contrato de mensajes, errores, secuencias y criterios de aceptación. **Fuente de verdad**: se cambia aquí primero. |
| [`docs/godot.md`](docs/godot.md) | Equipo Godot | Cómo implementar el contrato: autoload `Net`, lobby, QR, eventos, idempotencia y votaciones. |
| [`docs/controller.md`](docs/controller.md) | Mando web | Arquitectura Vue, rutas de rol (NFC), estados, recuperación de sesión, estilos y despliegue. |
| [`docs/backend.md`](docs/backend.md) | Backend / despliegue | Tecnologías, estructura, modelo de sala, reconexión y límites del MVP. |
| [`docs/Clases Godot.pdf`](docs/Clases%20Godot.pdf), [`docs/Eventos _ Games.pdf`](docs/Eventos%20_%20Games.pdf) | Diseño del juego | Material de diseño del equipo. |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code | Contexto y convenciones del proyecto para el asistente. |

## Empezar

Requisito: Node ≥ 22.

### Probarlo todo con un comando

```bash
npm install      # instala también backend/ y controller/
npm run dev
```

Arranca el **backend**, el **mando** (Vite) y un **anfitrión simulado** que hace de Godot en la terminal. El simulador crea una sala e imprime las URL para abrir desde el móvil (misma Wi-Fi), por ejemplo:

```text
[host]  Sala creada: K7MP
[host]    Móvil (misma red): http://192.168.1.50:5173/controller/?room=K7MP
[host]    Entrada por rol:   http://192.168.1.50:5173/controller/engineer  (también biologist, doctor, generalist)
```

Después se escriben comandos en esa misma terminal:

| Comando | Qué hace |
|---|---|
| `start` | Inicia la partida (todos los jugadores con rol) |
| `ask` | Envía un evento con opciones a todos los móviles; se resuelve solo cuando votan todos |
| `resolve` | Resuelve el evento actual con los votos recibidos |
| `wait` | Envía una pantalla de espera |
| `finish` | Termina la partida |
| `new` | Crea una sala nueva |
| `status` / `help` | Estado de la sala / ayuda |

Otras órdenes desde la raíz:

```bash
npm run dev:no-host   # backend + mando, sin simulador (para probar con el Godot real)
npm test              # tests del backend y del mando
npm run build         # genera dist/controller/
```

Los puertos se eligen solos. Si el 3000 está ocupado o reservado (en Windows, Hyper-V/WSL a veces lo reservan), el backend usa otro y el mando se configura con él. Si el móvil no carga, revisad que esté en la misma red y que el cortafuegos de Windows permita Node en redes privadas.

### Cada parte por separado

```bash
cd backend && npm run dev       # :3000 (PORT=<otro> para cambiarlo)
cd controller && npm run dev    # :5173/controller/ (BACKEND_PORT=<puerto del backend>)
npm run host                    # simulador contra un backend ya arrancado en :3000
```

### Godot

Abrir `game/project.godot` con Godot 4.7. Para exportar: **Proyecto → Exportar → Web** (genera `dist/game/index.html`).

### Todo junto (cuando exista `compose.yaml`)

```bash
docker compose up --build
```

Para que el QR funcione, la pantalla debe abrirse con la **IP de la LAN** (p. ej. `http://192.168.1.50`), no con `localhost`.

## Rutas

| Ruta | Qué sirve |
|---|---|
| `/` | Crear partida o entrar con código |
| `/game/` | Pantalla principal (Godot) |
| `/controller/` · `/controller/?room=K7MP` | Mando web (el QR precarga el código) |
| `/controller/engineer` · `/biologist` · `/doctor` · `/generalist` | Mando entrando directamente a un rol (tablero NFC) |
| `/ws` | WebSocket |
| `/api/health` | Comprobación del backend |

## Primer hito

Un botón real en un móvil cambia un texto en Godot exportado a web. Después, los criterios de aceptación de [`docs/protocol.md`](docs/protocol.md#criterios-de-aceptación).

## Convenciones

- Código en inglés; textos de interfaz y documentación en español.
- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `tipo(ámbito): descripción`. Ej.: `feat(backend): crear salas en memoria`.
- Cualquier cambio de mensajes se acuerda primero en `docs/protocol.md`.
