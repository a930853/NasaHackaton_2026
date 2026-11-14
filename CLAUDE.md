# CLAUDE.md

Juego cooperativo por salas para el NASA Hackathon 2026: una **pantalla principal en Godot** (exportada a web) y **hasta cuatro mandos web** (móviles) por partida. Un **backend Node** conecta a los participantes y mantiene las salas separadas. Todo se sirve con **Nginx** y se levanta con **Docker Compose** en la LAN.

## Regla fundamental (no romper nunca)

- **Godot es la autoridad sobre el juego**: eventos, reglas, recursos (oxígeno, energía, salud), validación y resolución de decisiones.
- **Node es la autoridad sobre la sesión**: quién está conectado, a qué sala pertenece y qué rol tiene.
- **El móvil solo envía elecciones** (`optionId`). Nunca calcula ni decide consecuencias.
- Node **no confía** en un `playerId` enviado por un móvil: la identidad sale de la conexión registrada (o de un `resumeToken` válido).

## Estructura

```text
game/              Proyecto Godot 4.7 (GDScript, GL Compatibility). Exporta a ../dist/game/
controller/        Mando web: HTML + CSS + JS sin framework. Se sirve en /controller/
landing/           Página de inicio "/" (crear partida o entrar con código)
backend/
  src/server.js    HTTP (/api/health) + WebSocket (/ws), enrutado de mensajes
  src/rooms.js     Modelo en memoria: salas, jugadores, roles, tokens
  src/protocol.js  Tipos de mensaje y validación de entrada
  package.json
  Dockerfile
deploy/nginx.conf  Sirve estáticos y hace proxy de /ws y /api al backend
dist/game/         Exportación web de Godot (generada)
compose.yaml       Servicios `web` (Nginx) y `backend` (Node)
docs/protocol.md   Contrato de mensajes: FUENTE DE VERDAD compartida
```

El lobby y las pantallas por rol son **estados internos del mando**, no aplicaciones separadas.

## Rutas

| Ruta | Qué sirve |
|---|---|
| `/` | `landing/` |
| `/game/` | `dist/game/` (Godot) |
| `/controller/` y `/controller/?room=K7MP` | `controller/` (precarga el código del QR) |
| `/ws` | WebSocket único para Godot y mandos |
| `/api/health` | Salud del backend |

Los clientes construyen la URL del WebSocket a partir de `location` (`ws(s)://<host>/ws`). **Nada de IPs fijas en el código.** Para el QR se usa una dirección LAN configurable (p. ej. `http://192.168.1.50`), nunca `localhost`.

## Protocolo

- JSON con campo `type` obligatorio. Lista de mensajes, campos y quién valida cada uno: `docs/protocol.md`.
- **Cualquier cambio de mensaje se hace primero en `docs/protocol.md`** y después en backend, Godot y mando. No inventar mensajes ni campos fuera del contrato.
- `eventId` identifica una aparición concreta de un evento; `actionId` identifica una pulsación lógica (idempotencia: un reenvío devuelve la confirmación anterior sin repetir efectos).

## Modelo de sala (backend)

- Salas en un `Map` en memoria. Reiniciar Node o recargar el anfitrión = partida nueva.
- Máximo 4 jugadores; un jugador por rol; roles `engineer`, `biologist`, `doctor`, `generalist`; los roles solo cambian en el lobby.
- Node genera códigos de sala (únicos), `playerId`, `hostToken` y `resumeToken` (aleatorios, con `crypto`). **El código de sala no es credencial.**
- `lastView` guarda la última `controller_view` de cada jugador para restaurarla al reconectar.
- Desconexión de móvil: se conserva jugador y rol, marcado `connected: false`. Desconexión del anfitrión: se cierra la sala y se envía `room_closed`.

## Reglas de eventos (Godot)

- Evento: `id`, `mode` (`individual` | `vote`), `eligiblePlayers`, `options`, `decisions`, `resolutionRule`.
- Se puede jugar con 1–4 jugadores: nunca asignar una decisión obligatoria a un rol ausente.
- Elección aceptada = bloqueada. Eventos antiguos rechazan decisiones. Empate → segunda votación entre empatadas → si persiste, desempata el anfitrión.
- Si falta un jugador necesario, se espera; el anfitrión puede omitir ausentes explícitamente.

## Comandos

```bash
# Backend en local (sin Docker)
cd backend && npm install && npm run dev

# Todo con Docker (tras exportar Godot a dist/game/)
docker compose up --build
```

Exportar Godot: abrir `game/project.godot` → Proyecto → Exportar → preset **Web** (apunta a `../dist/game/index.html`). `thread_support=false`, así que no hacen falta cabeceras COOP/COEP.

## Convenciones

- Código e identificadores en inglés; textos de interfaz y documentación en español.
- Backend: Node ≥ 20, ES modules, única dependencia de runtime `ws`.
- Mando: JS vanilla, mobile-first, sin dependencias externas en runtime (la demo debe funcionar en la LAN sin Internet).
- Godot: el autoload `Events` (`game/Scripts/events.gd`) es el bus de señales; la red irá en un autoload propio (p. ej. `Net`) que emita señales a `Events`.

## Primer hito

Un botón real en un móvil cambia un texto en Godot exportado a web. Después, verificar los criterios de aceptación del contrato (`docs/protocol.md`).
