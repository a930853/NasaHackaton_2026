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

### Backend

```bash
cd backend
npm install
npm run dev      # http://localhost:3000/api/health
npm test         # pruebas de integración
```

### Mando (con el backend en marcha)

```bash
cd controller
npm install
npm run dev      # http://localhost:5173/controller/ (también desde el móvil por la IP de la LAN)
npm test
npm run build    # genera dist/controller/
```

> **Windows:** si el backend falla con `listen EACCES` en el 3000, ese puerto está reservado por Hyper-V/WSL. Usad otro: `PORT=8787 npm run dev` en `backend/` y `BACKEND_PORT=8787 npm run dev` en `controller/`.

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
