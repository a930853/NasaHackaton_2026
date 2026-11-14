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
game_debug/        Proyecto Godot aparte (GL Compatibility) para probar la conexión con info de depuración. Exporta a ../dist/game_debug/
controller/        Mando web: Vue 3 + Vite + Tailwind 4 (JS). Compila a ../dist/controller/, se sirve en /controller/
  src/net/socket.js       Único punto que toca el WebSocket
  src/stores/session.js   Estado de la sesión e interpretación de mensajes
  src/views/, components/ Pantallas (solo leen el estado y llaman acciones)
landing/           Página de inicio "/" (crear partida o entrar con código)
backend/
  src/server.js    HTTP (/api/health) + WebSocket (/ws), enrutado de mensajes
  src/rooms.js     Modelo en memoria: salas, jugadores, roles, tokens
  src/protocol.js  Tipos de mensaje y validación de entrada
  package.json
  Dockerfile
deploy/web.Dockerfile     Imagen web: compila el mando y copia landing/ y dist/<GAME_EXPORT>/
deploy/nginx/default.conf HTTPS para todo (Godot web lo exige), estáticos y proxy de /ws y /api
deploy/nginx/15-cert.sh   Certificado autofirmado al arrancar (volumen `certs`)
scripts/dev.mjs    `npm run dev`: arranca backend y mando con puertos libres y log de mensajes
dist/game/         Exportación web de Godot (generada)
dist/game_debug/   Exportación web de game_debug (generada, se versiona)
dist/controller/   Build del mando (generado, no se versiona)
compose.yaml       Servicios `web` (Nginx) y `backend` (Node). Producción: sirve dist/game
compose.dev.yaml   Solo cambia GAME_EXPORT=game_debug y LOG_MESSAGES=1
docs/protocol.md   Contrato de mensajes: FUENTE DE VERDAD compartida
docs/controller.md, docs/backend.md, docs/deploy.md   Guías por componente
docs/godot/        arquitectura.md (gestores, FSM, events.json) y red.md (autoload Net)
docs/juego/        diseno.md (reglas y decisiones pendientes) y eventos.md (catálogo)
game/Data/events.json  Cifras de eventos y reglas: fuente de verdad del diseño numérico
```

El lobby y las pantallas por rol son **estados internos del mando**, no aplicaciones separadas. Las rutas de rol (`/controller/<rol>`) solo expresan la intención de rol (botón o etiqueta NFC del tablero físico); el rol real lo confirma el backend.

## Rutas

| Ruta | Qué sirve |
|---|---|
| `/` | `landing/` |
| `/game/` | `dist/game/` (Godot) |
| `/controller/` y `/controller/?room=K7MP` | `dist/controller/` (precarga el código del QR) |
| `/controller/<engineer\|biologist\|doctor\|generalist>` | Mismo mando, entrando directamente a ese rol (NFC). Nginx con *fallback* a `index.html` |
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
- Elección aceptada = bloqueada. Eventos antiguos rechazan decisiones. Empate → segunda votación entre empatadas → si persiste, se sortea entre ellas.
- Si falta un jugador necesario, se espera; el anfitrión puede omitir ausentes explícitamente.

## Comandos

```bash
# Todo desde la raíz (Node ≥ 22)
npm install                                   # instala también backend/ y controller/
npm run dev                                   # backend + mando, con LOG_MESSAGES=1 (mensajes en bruto)
npm test                                      # tests de backend y mando

# Backend en local (sin Docker)
cd backend && npm install && npm run dev      # :3000 (PORT para cambiarlo, LOG_MESSAGES=1 para ver mensajes)
cd backend && npm test

# Mando en local (necesita el backend)
cd controller && npm install && npm run dev   # http://localhost:5173/controller/ (BACKEND_PORT si no es 3000)
cd controller && npm test                     # store contra el backend real
cd controller && npm run build                # → dist/controller/

# Todo con Docker, por HTTPS (antes exportar a web el proyecto de Godot que se sirve)
npm run docker:dev                            # sirve dist/game_debug, con log de mensajes
npm run docker:prod                           # sirve dist/game
```

Exportar Godot: abrir `game/project.godot` → Proyecto → Exportar → preset **Web** (apunta a `../dist/game/index.html`). `thread_support=false`, así que no hacen falta cabeceras COOP/COEP. Godot 4 web sí exige contexto seguro (HTTPS o localhost): por eso Nginx sirve todo por HTTPS.

En Windows, Hyper-V/WSL pueden reservar el puerto 3000 (`listen EACCES`). Comprobar con `netsh interface ipv4 show excludedportrange protocol=tcp` y usar otro puerto (`PORT` en el backend, `BACKEND_PORT` en el mando).

## Convenciones

- Código e identificadores en inglés; textos de interfaz y documentación en español.
- Commits con [Conventional Commits](https://www.conventionalcommits.org/es/): `tipo(ámbito): descripción`. Tipo en inglés (`feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`, `build`), descripción en español, en minúscula y sin punto final. Ámbitos: `game`, `controller`, `backend`, `deploy`, `docs`. Ej.: `feat(backend): crear salas en memoria`.
- Backend: Node ≥ 20, ES modules, dependencias de runtime `express` (HTTP) y `ws` (WebSocket); tests con `node:test` (`npm test`).
- Mando: Vue 3 (`<script setup>`, JS) + `vue-router` + Tailwind 4, mobile-first. Estilos con utilidades de Tailwind; el color del rol va por variables CSS (`--role-color`…). Nada cargado de Internet (fuentes con `@fontsource`): la demo funciona en la LAN sin conexión exterior.
- Godot: el autoload `Events` (`game/Scripts/events.gd`) es el bus de señales; la red irá en un autoload propio (p. ej. `Net`) que emita señales a `Events`.

## Primer hito

Un botón real en un móvil cambia un texto en Godot exportado a web. Después, verificar los criterios de aceptación del contrato (`docs/protocol.md`).
