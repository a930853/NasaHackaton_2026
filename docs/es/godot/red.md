# Red en Godot: conexión con el backend y los móviles

Cómo conectar `game/` con el backend siguiendo el [contrato de mensajes](../protocol.md). La organización del resto del juego (gestores, máquina de estados, `events.json`) está en [arquitectura.md](arquitectura.md). Los fragmentos de código son versiones resumidas de `game/Scripts/` (GDScript, Godot 4.x); la referencia es siempre el código.

## Estado de la implementación (`game/`)

Ya está conectado el juego real con el backend y el mando web. Piezas:

| Pieza | Fichero | Qué hace |
|---|---|---|
| `Net` (autoload) | `game/Scripts/net.gd` | Único sitio que toca el WebSocket. Emite las señales de red en `Events` y expone `create_room()`, `start_game()`, `send_view()`, `send_result()`, `finish_game()`. |
| `PhoneBridge` (autoload) | `game/Scripts/phone_bridge.gd` | Une `TurnManager` con los móviles: envía a cada jugador su `controller_view`, **valida** cada `choose` (evento vigente, jugador, opción, duplicados por `actionId`) y responde siempre con `choice_result`. |
| Lobby | `game/Scripts/main_menu.gd` (nodo `Lobby` de `Main_menu.tscn`) | «Start Game» pregunta el modo: **Play solo** (una pantalla, sin móviles ni red) o **Play multiplayer**. En multijugador conecta, crea la sala y enseña código, dirección del mando y jugadores con su rol; «Start expedition» se activa cuando hay ≥1 jugador y todos tienen rol; «Play solo instead» y «Back» salen del lobby (p. ej. si no hay servidor, que se detecta a los 4 s). |
| Señales | `game/Scripts/events.gd` | `net_connected`, `net_disconnected`, `net_connection_failed`, `room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `player_continue_received`, `room_closed`, `net_error`. |

El lobby usa la estética del juego: marco azul de los botones, tarjetas de jugador con el casco del color de su rol (4 plazas, las libres apagadas y el comandante marcado), el código de la sala en una caja destacada y el QR sobre fondo blanco con marco azul.

Flujo de una partida: menú → lobby (sala creada, móviles entran y eligen rol) → `start_game` → intro → partida. En cada evento, `TurnManager` emite `event_presented` y `PhoneBridge` manda a cada móvil **todas las opciones** del evento, sean de su rol o no (`TurnManager.controller_view_for(role)`: con `detail` = costes, y `disabled` + `reason` si el rol está ocupado fuera de la base). Al resolverse, todos reciben una vista `result` con las consecuencias. Al volver al menú se cierra la sala (`finish_game`).

Decisiones tomadas:

- **Dirección del servidor:** en web, `location` (nunca IP fija). En el editor, `ws://localhost:3000/ws`; se puede cambiar con el argumento `--ws-url=ws://localhost:3100/ws` o la variable de entorno `NASA_WS_URL`.
- **Dirección del mando que se enseña:** en web, `location.origin`; en el editor, `http://localhost:5173` (Vite). Si contiene `localhost` el lobby avisa de que los móviles no podrán usarla.
- **QR:** el lobby multijugador lo enseña a la derecha de las instrucciones, con `Net.controller_url(code)`. Lo genera `game/Scripts/qr_code.gd` (`QrCode.to_texture(texto)`), un generador en GDScript sin dependencias (modo byte, corrección M, versiones 1–10, hasta 213 bytes). El **código en texto** y la dirección siguen visibles como plan B, y la landing (`/`) permite entrar escribiendo el código.
- **Todos votan todas las opciones:** cada móvil recibe todas las opciones del evento. Las que tienen un rol dueño llevan su nombre delante (`(Engineer) …`) y quien la haga queda ocupado. Si solo votara el dueño del rol, su opción casi nunca saldría elegida. Un rol ausente (menos de 4 jugadores) no deja ninguna decisión sin dueño. Si todos los presentes están ocupados fuera, el evento espera a que vuelva alguien.
- **Quién decide (votación):** cada jugador conectado y en la base vota una opción (`TurnManager.cast_vote`). Cuando han votado todos los que pueden, gana la más votada. Un voto aceptado queda bloqueado (otro `actionId` → `already_decided`) y el móvil pasa a una vista `waiting` «Vote sent!» con el recuento. Un móvil desconectado no bloquea la votación.
- **Empates:** segunda votación solo entre las empatadas, con nuevo `eventId` (`<id>#<n>-tie`), así que un voto tardío de la primera ronda recibe `event_closed`. Si vuelve a empatar, decide el voto del Comandante (el primer jugador que entró) y el resultado lo dice («It was a tie again, so the Commander's vote decided!»). Si se acaba la cuenta atrás de un evento crítico, gana lo más votado hasta ese momento (o la opción por defecto si no hay votos).
- **Rechazos:** `choice_result` con `event_closed`, `not_eligible`, `invalid_option` o `already_decided`. El backend no reenvía `choice_result` al mando; el mando se entera por la siguiente `controller_view`.
- **Si cae el backend:** `PhoneBridge` se desactiva y la partida sigue en la pantalla principal como en el modo solitario: las opciones se eligen con el ratón.

Probarlo: `npm run dev` (la terminal imprime los puertos que usa: el backend intenta el 3000 y, si está ocupado, otro libre; en ese caso hay que lanzar el juego con `--ws-url`), abrir `game/` en Godot y pulsar F5; abrir `http://localhost:5173/controller/?room=<código>` en el navegador. Para el despliegue completo, exportar a web (`dist/game/`) y `npm run docker:local`.

## Qué le toca a Godot

Godot es **la autoridad sobre el juego** y, además, el cliente *anfitrión* de la sala:

1. Crear la sala, mostrar código y QR, y pintar el lobby.
2. Iniciar la partida.
3. Abrir eventos y enviar a cada mando **su** vista.
4. **Validar** cada `choose` (evento vigente, opción válida, jugador habilitado, duplicados).
5. Resolver el evento, aplicar consecuencias (oxígeno, energía, salud…) y avanzar.
6. Confirmar o rechazar cada elección con `choice_result`.

Node solo garantiza quién es quién. Que un mensaje llegue **no** significa que sea válido para el juego.

## Arquitectura

```text
Net (autoload, game/Scripts/net.gd)   ← único sitio que toca el WebSocket
  │  emite señales en Events
  ▼
Events (autoload existente)           ← bus de señales
  ▲
  │  escuchan
GameState / EventManager / Lobby UI   ← lógica y pantallas
```

- **`Net`** abre el socket, hace `poll()`, parsea JSON y emite señales. También expone funciones para enviar (`create_room()`, `start_game()`, `send_view()`, `send_result()`…). El resto del juego **no** conoce el WebSocket.
- **`Events`** (`game/Scripts/events.gd`) es el bus de señales y ya contiene todas las señales de red (lista abajo).
- La lógica de eventos (`TurnManager`) no depende de `Net`: `PhoneBridge` escucha sus señales y las de red, y llama a `Net.send_view(...)` / `Net.send_result(...)`.

### Señales de red en `events.gd`

```gdscript
# --- Network (Node backend) ---
signal net_connected
signal net_disconnected
signal room_created(code: String)
signal lobby_updated(players: Array, status: String)   # lobby_state
signal game_started(players: Array)
signal net_connection_failed
signal player_choice_received(player_id: String, role: String, action_id: String, event_id: String, option_id: String)
signal player_continue_received(player_id: String, role: String, action_id: String)
signal room_closed(reason: String)
signal net_error(code: String, request_type: String)
```

## Conexión

### Dirección del servidor

La URL se construye desde el sitio que sirvió la página. **Nunca** una IP fija. Es `Net.default_url()` (resumido):

```gdscript
func default_url() -> String:
	if OS.has_feature("web"):
		var proto: String = str(JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'"))
		var host: String = str(JavaScriptBridge.eval("location.host"))
		return "%s://%s/ws" % [proto, host]
	# Fuera del navegador: argumento --ws-url=..., variable NASA_WS_URL o, si no, la dirección local.
	...
	return "ws://localhost:3000/ws"
```

> En el editor (no web) no hay `location`; se usa el backend local. `npm run dev` intenta el puerto 3000 y, si no está libre, usa otro y lo imprime: entonces lanzad el juego con `--ws-url=ws://localhost:<puerto>/ws` (o `NASA_WS_URL`). Para probar la integración completa, exportad a web y servid con Docker.

### Autoload `Net` (esqueleto)

```gdscript
extends Node
# game/Scripts/net.gd  → Proyecto > Ajustes > Autoload, nombre "Net"

var _ws := WebSocketPeer.new()
var _was_open := false
var room_code := ""
var players: Array = []            # último lobby_state.players

func connect_to_server() -> void:
	var err := _ws.connect_to_url(default_url())
	if err != OK:
		push_error("Net: no se pudo conectar (%s)" % err)

func _process(_delta: float) -> void:
	_ws.poll()   # OBLIGATORIO cada frame, si no no se envía ni se recibe nada
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				Events.net_connected.emit()
			while _ws.get_available_packet_count() > 0:
				_on_text(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				Events.net_disconnected.emit()   # el anfitrión no se recupera: ver "Desconexiones"

func _send(msg: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))

func _on_text(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("type"):
		return
	match msg["type"]:
		"room_created":
			room_code = msg["code"]
			Events.room_created.emit(room_code)
		"lobby_state":
			players = msg["players"]
			Events.lobby_updated.emit(players, msg["status"])
		"game_started":
			players = msg["players"]
			Events.game_started.emit(players)
		"choose":
			Events.player_choice_received.emit(
				msg["playerId"], msg["role"], msg["actionId"], msg["eventId"], msg["optionId"])
		"room_closed":
			Events.room_closed.emit(msg.get("reason", ""))
		"error":
			Events.net_error.emit(msg.get("code", ""), msg.get("requestType", ""))

# --- API hacia el resto del juego ---
func create_room() -> void: _send({"type": "create_room"})
func start_game() -> void: _send({"type": "start_game"})
func finish_game() -> void: _send({"type": "finish_game"})

func send_view(player_id: String, view: Dictionary) -> void:
	_send({"type": "controller_view", "playerId": player_id, "view": view})

func send_result(player_id: String, action_id: String, accepted: bool, reason := "") -> void:
	var msg := {"type": "choice_result", "playerId": player_id, "actionId": action_id, "accepted": accepted}
	if not accepted:
		msg["reason"] = reason
	_send(msg)
```

Detalles que suelen fallar:

- `WebSocketPeer` **no** es asíncrono por señales: hay que llamar a `poll()` en cada frame.
- Los mensajes llegan como `PackedByteArray`; se convierten con `get_string_from_utf8()`.
- `JSON.parse_string` devuelve `null` si el JSON es inválido. Comprobad el tipo.
- Todos los identificadores del contrato (`playerId`, `eventId`, `actionId`, `optionId`) son `String`; no los convirtáis a números.

## Lobby

1. Al arrancar la pantalla: `Net.connect_to_server()`; al emitirse `net_connected`, `Net.create_room()`.
2. `room_created` → mostrar el **código** y el **QR** (ver abajo).
3. Cada `lobby_updated` trae la lista completa: **repintad el lobby entero**, no intentéis aplicar diferencias. Marcad en gris a los de `connected == false`.
4. El botón "Iniciar" se habilita si `players.size() >= 1` y todos tienen `role != null`. Si pulsa antes, Node responderá `error` (`players_without_role`, `no_players`); mostradlo, pero deshabilitar el botón evita el caso normal.
5. `Net.start_game()` → llega `game_started` con los jugadores definitivos. **Guardad esa lista**: define qué roles existen en la partida.

### Código QR

El QR debe contener `<dirección-LAN>/controller/?room=<código>`.

- La base es `location.origin` (en el editor, `http://localhost:5173`) y la dirección completa la da `Net.controller_url(code)`. Si contiene `localhost`/`127.0.0.1` (`Net.controller_url_is_local()`), el lobby avisa de que los móviles no podrán usarla: hay que abrir el juego por la dirección de la LAN (p. ej. `http://192.168.1.50`). No hay campo para escribir la IP a mano.
- Godot no trae generador de QR: se usa `game/Scripts/qr_code.gd`, en GDScript y sin dependencias (funciona igual en escritorio y en web).
- Mostrad siempre también el código en texto: es el plan B si falla el QR.

```gdscript
func controller_url(code: String) -> String:
	return "%s/controller/?room=%s" % [controller_base_url(), code]
```

## Eventos

### Modelo

Los eventos salen de `game/Data/events.json` y los lleva `TurnManager` (ver [arquitectura.md](arquitectura.md)). Todos se deciden **por votación** entre los jugadores; no hay eventos `individual` ni lista `eligible_players` por evento. Lo que guarda `TurnManager` del evento vigente:

```gdscript
var current_event: Dictionary          # la plantilla de events.json (id, title, options…)
var current_event_uid: String          # "storm-01#3" → el eventId de ESTA aparición (ver abajo)
var _votes: Dictionary = {}            # role -> optionId (votos aceptados, bloqueados)
var _tie_options: Array[String] = []   # en el desempate, las únicas opciones que se pueden votar
```

La idempotencia la lleva `PhoneBridge`: `_results` (`actionId -> {accepted, reason}`), con memoria de los últimos resultados.

### `eventId`: una aparición, no una plantilla

`eventId` es **único por aparición** del evento en esa partida: `TurnManager` lo forma con la plantilla y un contador global (`<id>#<n>`, p. ej. `storm-01#1`, `storm-01#2`; el desempate añade `-tie`). Así un `choose` rezagado de una aparición anterior se reconoce como antiguo y se rechaza con `event_closed`.

### Roles presentes y opciones

Con 1–4 jugadores, ningún evento puede quedar sin quien decida. Por eso **todos votan todas las opciones**:

- `TurnManager.controller_view_for(role)` da a cada móvil **todas** las opciones del evento. Las que tienen un rol dueño llevan su nombre delante (`(Engineer) …`), pero cualquier jugador puede votarlas, esté o no ese rol en la partida. Si el rol dueño está ocupado fuera de la base (o la opción exige a toda la tripulación en la base), la opción llega con `disabled` y `reason`.
- Votan los roles **conectados**, en la base y con alguna opción libre (`TurnManager.voters()`). Un móvil desconectado no bloquea la votación: al cambiar `connected`, `TurnManager` vuelve a comprobar si ya han votado todos. Si no queda nadie que pueda votar, el evento espera.
- Quien no puede votar recibe igualmente una vista `waiting` («You are busy!», «Read the story!», «Vote sent!»…) para no quedarse con la pantalla anterior. Mientras se lee la historia en la pantalla principal también llega `waiting`, y las opciones salen al acabar la lectura.

### Validar un `choose`

Orden que sigue `PhoneBridge._on_choice` (`game/Scripts/phone_bridge.gd`) al recibir `player_choice_received`; las comprobaciones del evento están en `TurnManager.choice_reject_reason` (`game/Scripts/turn_manager.gd`). Resumido:

```gdscript
# PhoneBridge
func _on_choice(player_id: String, role: String, action_id: String, event_id: String, option_id: String) -> void:
	if not active:
		Net.send_result(player_id, action_id, false, "event_closed")
		return
	# 1. Duplicado (mismo actionId): misma respuesta, SIN repetir efectos.
	if _results.has(action_id):
		var previous: Dictionary = _results[action_id]
		Net.send_result(player_id, action_id, bool(previous["accepted"]), str(previous["reason"]))
		return
	# 2. ¿El jugador existe en la partida? (la identidad la garantiza Node)
	if not _is_player(player_id):
		_reject(player_id, action_id, "not_eligible")
		return
	# 3. Evento vigente, rol libre y opción válida.
	var reason: String = TurnManager.choice_reject_reason(role, event_id, option_id)
	if not reason.is_empty():
		_reject(player_id, action_id, reason)   # memoriza el rechazo y reenvía la vista vigente
		return
	# 4. Aceptar el voto (con el último que faltaba, TurnManager resuelve).
	_remember(action_id, true, "")
	Net.send_result(player_id, action_id, true)
	TurnManager.cast_vote(role, event_id, option_id)

# TurnManager
func choice_reject_reason(role: String, event_uid: String, option_id: String) -> String:
	if event_uid != current_event_uid or phase != Phase.DECISION or reading:
		return "event_closed"
	if GameState.is_away(role):
		return "not_eligible"
	if _votes.has(role):
		return "already_decided"
	var option: Dictionary = _find_option(current_event, option_id)
	if option.is_empty() or not option_block_reason(option).is_empty():
		return "invalid_option"
	if not _tie_options.is_empty() and not (option_id in _tie_options):
		return "invalid_option"
	return ""
```

Puntos clave:

- **Idempotencia**: se guarda `actionId → resultado` y se responde igual las veces que haga falta. Una doble pulsación o un reenvío tras reconexión **no** puede aplicar la consecuencia dos veces. Los rechazos también se memorizan.
- Se responde **siempre** con un `choice_result` para que Node pueda validar el flujo; el mando no lo recibe. Después llega una nueva `controller_view` con el resultado, la espera («Vote sent!») o la siguiente pregunta.
- La identidad (`player_id`, `role`) viene de Node y es fiable; nunca se lee del contenido que mande el móvil.
- `already_decided` con un **`actionId` distinto**: el jugador ya votó y pulsó otra cosa. Con el mismo `actionId` es un duplicado (paso 1) y no un error.

### Resolver

Cuando ha votado el último de los que pueden votar (`TurnManager._try_resolve_votes`), gana la opción más votada.

**Empates:** nueva votación **solo entre las opciones empatadas**, con nuevo `eventId` (`<id>#<n>-tie`). Si vuelve a empatar, **decide el voto del Comandante** (si no votó ninguna de las empatadas, la primera de ellas). Si se acaba la cuenta atrás de un evento crítico, gana lo más votado hasta ese momento (o la opción por defecto si no hay votos).

Al resolver:

1. El evento se cierra: los `choose` que lleguen después reciben `event_closed`.
2. Se aplican las consecuencias a los recursos (solo aquí, nunca al recibir el `choose`).
3. Cada jugador recibe una vista `result` con `canContinue: true`; cuando todos los conectados confirman (`continue`), se pasa al siguiente Sol. El anfitrión también puede avanzar desde la pantalla principal.
4. Se emiten las señales de juego (`oxygen_level_changed`, etc.) para actualizar la UI.

### Jugadores ausentes

`lobby_updated` sigue llegando durante la partida con `connected` actualizado.

- Un jugador desconectado **no bloquea** el evento: deja de contar como votante y se resuelve con los votos de los conectados. No hay botón para omitir ausentes porque no hace falta.
- Cuando un jugador **reconecta**, Node le reenvía su última `controller_view`, y además `PhoneBridge` le manda la vista vigente al ver que vuelve a `connected == true` (por si el evento se resolvió mientras estaba fuera).

### Fin de partida

Al acabar la misión los móviles reciben una vista `result` con `canContinue: false` y la puntuación. `Net.finish_game()` se llama al volver al menú: los mandos reciben `room_closed` (`game_finished`) y la sala deja de existir.

## Desconexiones

| Situación | Qué hace Godot |
|---|---|
| Se cae el WebSocket del propio anfitrión (`net_disconnected`) | La sala ya no existe en Node y los mandos han recibido `room_closed`. En el lobby se avisa y se ofrece «Back» o «Play solo instead»; en partida, `PhoneBridge` se desactiva y se sigue jugando en la pantalla principal. No se reconecta a la misma sala. |
| Recargar la pestaña del anfitrión | Equivale a lo anterior: partida nueva. |
| Se desconecta un móvil | Llega `lobby_updated` con `connected: false`. Se mantienen su rol y su voto; deja de contar como votante. |
| Reinicio del backend | Mismo caso que caída del anfitrión. |

## Exportación web

- Preset **Web** en `game/export_presets.cfg` → `../dist/game/index.html`. `thread_support=false`, así que **no hacen falta cabeceras COOP/COEP** y Nginx se mantiene simple.
- Godot 4 web **solo arranca en un contexto seguro** (HTTPS o `localhost`). Por eso el despliegue sirve todo por HTTPS y el WebSocket es `wss://` (lo deduce `Net.default_url()` de `location.protocol`). Ver [../deploy.md](../deploy.md).
- **Pantalla de carga propia** (sustituye a la de Godot): un cohete en pixel art sale de la Tierra, pasa por la Luna y llega a Marte según avanza la descarga; al terminar aterriza y la pantalla se funde con el juego. Es una plantilla web propia: el preset Web usa `html/custom_html_shell="res://web/loading_shell.html"` (y `exclude_filter="web/*"` para que no vaya dentro del `.pck`). Los ficheros:
  - `game/web/loading_shell.template.html`: la plantilla, que se **edita a mano**. Conserva los marcadores `$GODOT_...` de Godot y el arranque (`engine.startGame`, `onProgress`, avisos de error).
  - `tools/build_loading_shell.py`: mete en la plantilla, como data URI, las imágenes `tierra.png`, `luna.png`, `Marte.png` y `Cohete.png` de `game/Images/` y la fuente, y genera `game/web/loading_shell.html`. **Hay que ejecutarlo tras cambiar la plantilla o esas imágenes y antes de exportar.**
  - Para ver la animación sin esperar a una descarga lenta, servir `dist/game/` en `localhost` y abrir `index.html?fakeload=10` (10 s de carga simulada). El viaje dura como mínimo unos 3 s aunque el juego cargue al instante.
- Exportad siempre a `dist/game/` antes de levantar Docker (`npm run docker:local`).
- `JavaScriptBridge` y `OS.has_feature("web")` solo funcionan en la exportación web. Protegedlo con `OS.has_feature("web")` para poder seguir probando desde el editor.
- Todos los recursos (fuentes, audio, imágenes) deben ir dentro del `.pck`; la demo no puede depender de Internet. Las llamadas a las APIs de la NASA (`nasa_api.gd`, que lanza `main.gd`, y la de DONKI en `turn_manager.gd`) tienen que fallar con gracia si no hay conexión.

## Cómo probar

1. Desde la raíz: `npm run dev` (backend + mando + landing). Fijaos en el puerto que imprime para el backend. En esa terminal se ven todos los mensajes que pasan por el backend (`←` recibidos, `→` enviados), útil para ver qué manda Godot y qué le llega.
2. Lanzad el juego desde el editor apuntando a `ws://localhost:<puerto>/ws` (por defecto el 3000; si es otro, con `--ws-url`).
3. Abrid el mando en el móvil (`http://<IP-del-PC>:5173/controller/?room=<código>`) o en otra pestaña del PC.
4. Sin móviles, también vale cualquier cliente WebSocket (p. ej. `npx wscat -c ws://localhost:<puerto>/ws`) enviando a mano `join_room`, `select_role` y `choose`.
## Checklist de Godot

Estado de lo implementado en `game/`:

- [x] `Net` hace `poll()` cada frame y centraliza el socket.
- [x] Lobby pintado desde `lobby_state` completo, con jugadores desconectados diferenciados.
- [x] QR (o enlace) con la dirección de la página y aviso si es `localhost`; código visible también en texto.
- [x] Cada evento tiene `eventId` único por aparición (`<id>#<n>`, `-tie` en el desempate).
- [x] Un evento nunca depende de un rol ausente (todos votan todas las opciones).
- [x] `actionId` repetido → misma respuesta, sin efectos duplicados.
- [x] `choose` de un evento anterior → `event_closed`.
- [x] Todo `choose` recibe un `choice_result`.
- [x] Empate → segunda votación entre las empatadas → si persiste, decide el voto del Comandante.
- [x] Tras `net_disconnected`: en el lobby se ofrece volver o jugar en solitario; en partida se sigue en la pantalla principal.
