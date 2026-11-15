# NasaHackaton 2026

Juego cooperativo por salas para el NASA Hackathon 2026. Una **pantalla principal en Godot** (exportada a web) y **hasta cuatro mandos web** (móviles) por partida, conectados por un **backend Node** que mantiene las salas separadas. Se sirve con **Nginx** y se levanta con **Docker Compose** en la red local.

> **Regla fundamental:** Godot es la autoridad sobre el juego; Node, sobre quién está conectado, en qué sala y con qué rol. El móvil solo envía elecciones; nunca decide consecuencias.

## Cómo encaja todo

```text
 Pantalla (Godot, web) ──┐
                         ├── WebSocket /ws ──► Backend Node ◄── Mandos (móviles)
 Mandos (HTML/JS) ───────┘        (Nginx sirve los archivos, cifra con HTTPS y hace de proxy)
```

## Estructura

| Carpeta | Contenido | Estado |
|---|---|---|
| [`game/`](game/) | Proyecto Godot 4.7 (GDScript) | En desarrollo |
| [`game_debug/`](game_debug/) | Proyecto Godot aparte para probar la conexión con información de depuración | En desarrollo |
| [`backend/`](backend/) | Servidor Node (Express + `ws`) | Implementado, con tests |
| [`controller/`](controller/) | Mando web (Vue 3 + Vite + Tailwind) | Implementado, con tests |
| [`landing/`](landing/) | Página de inicio `/` (Vue + Vite + Tailwind): qué es el juego y cómo jugar | Implementado |
| [`deploy/`](deploy/) | Imagen de Nginx de la app y proxy HTTPS para local | Implementado |
| [`scripts/`](scripts/) | `npm run dev` (backend + mando) | Herramientas de desarrollo |
| `dist/game/` | Exportación web de Godot | Se genera al exportar (se versiona: hay que volver a exportar y subirla tras cambiar `game/`) |
| `dist/game_debug/` | Exportación web de `game_debug` | Se genera al exportar (se versiona) |
| `dist/controller/` | Build del mando | Se genera con `npm run build` (no se versiona) |
| [`docs/`](docs/) | Documentación | Ver abajo |
| `compose.yaml` | Despliegue principal: Internet con Coolify | Implementado |
| `compose.local.yaml`, `compose.dev.yaml` | Despliegue en local (juego o depuración) | Implementado |

## Documentación

Índice completo y qué leer según tu papel: [`docs/README.md`](docs/README.md).

| Documento | Para quién | Qué cuenta |
|---|---|---|
| [`docs/protocol.md`](docs/protocol.md) | **Todos** | Contrato de mensajes, errores, secuencias y criterios de aceptación. **Fuente de verdad**: se cambia aquí primero. |
| [`docs/juego/diseno.md`](docs/juego/diseno.md) | **Todos** | Reglas del juego: bucle de un Sol, roles, recursos, objetivos, APIs de la NASA y **decisiones pendientes**. |
| [`docs/juego/eventos.md`](docs/juego/eventos.md) | Diseño / Godot | Catálogo de eventos con opciones, efectos y fuentes de la NASA. Las cifras salen de `game/Data/events.json`. |
| [`docs/godot/arquitectura.md`](docs/godot/arquitectura.md) | Equipo Godot | Gestores, máquina de estados del Sol, modelos y formato de `events.json`. |
| [`docs/godot/red.md`](docs/godot/red.md) | Equipo Godot | Cómo implementar el contrato: autoload `Net`, lobby, QR, eventos, idempotencia y votaciones. |
| [`docs/controller.md`](docs/controller.md) | Mando web | Arquitectura Vue, rutas de rol (NFC), estados, recuperación de sesión, estilos y despliegue. |
| [`docs/backend.md`](docs/backend.md) | Backend | Tecnologías, estructura, modelo de sala, reconexión y límites del MVP. |
| [`docs/deploy.md`](docs/deploy.md) | Despliegue | Internet con Coolify, despliegue en local y problemas habituales. |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code | Contexto y convenciones del proyecto para el asistente. |

## Empezar

Requisito: Node ≥ 22.

### Probarlo todo con un comando

```bash
npm install      # instala también backend/ y controller/
npm run dev
```

Arranca el **backend** y el **mando** (Vite). La sala la crea el anfitrión (Godot); después, el mando se abre desde el móvil (misma Wi-Fi) en `http://<IP-del-PC>:5173/controller/?room=<código>`.

En la misma terminal se ven **todos los mensajes en bruto** que pasan por el backend (`←` recibidos, `→` enviados, y con quién):

```text
[backend]    ← host K7MP     {"type":"start_game"}
[backend]    → K7MP/p1       {"type":"game_started","players":[...]}
```

Para quitarlo: `LOG_MESSAGES=0 npm run dev`.

Otras órdenes desde la raíz:

```bash
npm test              # tests del backend y del mando
npm run build         # genera dist/controller/
```

Los puertos se eligen solos. Si el 3000 está ocupado o reservado (en Windows, Hyper-V/WSL a veces lo reservan), el backend usa otro y el mando se configura con él. Si el móvil no carga, revisad que esté en la misma red y que el cortafuegos de Windows permita Node en redes privadas.

### Cada parte por separado

```bash
cd backend && npm run dev       # :3000 (PORT=<otro> para cambiarlo, LOG_MESSAGES=1 para ver mensajes)
cd controller && npm run dev    # :5173/controller/ (BACKEND_PORT=<puerto del backend>)
```

### Godot

Abrir `game/project.godot` con Godot 4.7. Para exportar: **Proyecto → Exportar → Web** (genera `dist/game/index.html`).

### Despliegue con Docker

El despliegue principal es **en Internet con Coolify**: un recurso *Docker Compose* con `compose.yaml` y el dominio en el servicio `web`. Coolify pone el HTTPS (Let's Encrypt).

En local, con HTTPS y certificado autofirmado:

```bash
npm run docker:local   # el juego (dist/game)
npm run docker:dev     # la pantalla de depuración (dist/game_debug), con log de mensajes
```

En local la pantalla se abre con la **IP de la LAN** (`https://192.168.1.50/game/`), no con `localhost`, y la primera vez cada navegador avisa del certificado. Detalles: [`docs/deploy.md`](docs/deploy.md).

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

- Código en inglés. Textos del juego y del mando en inglés sencillo (niños de 7 a 12 años). Documentación en español.
- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `tipo(ámbito): descripción`. Ej.: `feat(backend): crear salas en memoria`.
- Cualquier cambio de mensajes se acuerda primero en `docs/protocol.md`.
