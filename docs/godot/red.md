# Red en Godot: conexión con el backend y los móviles

Cómo conectar `game/` con el backend siguiendo el [contrato de mensajes](../protocol.md). La organización del resto del juego (gestores, máquina de estados, `events.json`) está en [arquitectura.md](arquitectura.md). Los fragmentos son una propuesta de punto de partida (GDScript, Godot 4.x); adaptadlos al estilo del proyecto.

## Estado de la implementación (`game/`)

Ya está conectado el juego real con el backend y el mando web. Piezas:

| Pieza | Fichero | Qué hace |
|---|---|---|
| `Net` (autoload) | `game/Scripts/net.gd` | Único sitio que toca el WebSocket. Emite las señales de red en `Events` y expone `create_room()`, `start_game()`, `send_view()`, `send_result()`, `finish_game()`. |
| `PhoneBridge` (autoload) | `game/Scripts/phone_bridge.gd` | Une `TurnManager` con los móviles: envía a cada jugador su `controller_view`, **valida** cada `choose` (evento vigente, jugador, opción, duplicados por `actionId`) y responde siempre con `choice_result`. |
| Lobby | `game/Scripts/main_menu.gd` (nodo `Lobby` de `Main_menu.tscn`) | «Start Game» pregunta el modo: **Play solo** (una pantalla, sin móviles ni red) o **Play multiplayer**. En multijugador conecta, crea la sala y enseña código, dirección del mando y jugadores con su rol; «Start expedition» se activa cuando hay ≥1 jugador y todos tienen rol; «Play solo instead» y «Back» salen del lobby (p. ej. si no hay servidor, que se detecta a los 4 s). |
| Señales | `game/Scripts/events.gd` | `net_connected`, `net_disconnected`, `net_connection_failed`, `room_created`, `lobby_updated`, `game_started`, `player_choice_received`, `room_closed`, `net_error`. |

Flujo de una partida: menú → lobby (sala creada, móviles entran y eligen rol) → `start_game` → intro → partida. En cada evento, `TurnManager` emite `event_presented` y `PhoneBridge` manda a cada móvil **todas las opciones** del evento, sean de su rol o no (`TurnManager.controller_view_for(role)`: con `detail` = costes, y `disabled` + `reason` si el rol está ocupado fuera de la base). Al resolverse, todos reciben una vista `result` con las consecuencias. Al volver al menú se cierra la sala (`finish_game`).

Decisiones tomadas:

- **Dirección del servidor:** en web, `location` (nunca IP fija). En el editor, `ws://localhost:3000/ws`; se puede cambiar con el argumento `--ws-url=ws://localhost:3100/ws` o la variable de entorno `NASA_WS_URL`.
- **Dirección del mando que se enseña:** en web, `location.origin`; en el editor, `http://localhost:5173` (Vite). Si contiene `localhost` el lobby avisa de que los móviles no podrán usarla.
- **QR:** pendiente. Godot no trae generador y de momento se muestran el **código en texto** y la dirección completa (plan B del contrato). La landing (`/`) también permite entrar escribiendo el código.
- **Todos votan todas las opciones:** cada móvil recibe todas las opciones del evento. Las que tienen un rol dueño llevan su nombre delante (`(Engineer) …`) y quien la haga queda ocupado. Si solo votara el dueño del rol, su opción casi nunca saldría elegida. Un rol ausente (menos de 4 jugadores) no deja ninguna decisión sin dueño. Si todos los presentes están ocupados fuera, el evento espera a que vuelva alguien.
- **Quién decide (votación):** cada jugador conectado y en la base vota una opción (`TurnManager.cast_vote`). Cuando han votado todos los que pueden, gana la más votada. Un voto aceptado queda bloqueado (otro `actionId` → `already_decided`) y el móvil pasa a una vista `waiting` «Vote sent!» con el recuento. Un móvil desconectado no bloquea la votación.
- **Empates:** segunda votación solo entre las empatadas, con nuevo `eventId` (`<id>#<n>-tie`), así que un voto tardío de la primera ronda recibe `event_closed`. Si vuelve a empatar, se sortea entre las empatadas y el resultado lo dice («It was a tie again, so luck decided!»). Si se acaba la cuenta atrás de un evento crítico, gana lo más votado hasta ese momento (o la opción por defecto si no hay votos).
- **Rechazos:** `choice_result` con `event_closed`, `not_eligible` o `invalid_option`. El backend no reenvía `choice_result` al mando; el mando se entera por la siguiente `controller_view`.
- **Si cae el backend:** `PhoneBridge` se desactiva y la partida sigue en la pantalla principal (con el panel `Phone (debug)`).

Probarlo: `npm run dev` (backend en `:3000`), abrir `game/` en Godot y pulsar F5; abrir `http://localhost:5173/controller/?room=<código>` en el navegador. Para el despliegue completo, exportar a web (`dist/game/`) y `npm run docker:prod`.

## Qué le toca a Godot

Godot es **la autoridad sobre el juego** y, además, el cliente *anfitrión* de la sala:

1. Crear la sala, mostrar código y QR, y pintar el lobby.
2. Iniciar la partida.
3. Abrir eventos y enviar a cada mando **su** vista.
4. **Validar** cada `choose` (evento vigente, opción válida, jugador habilitado, duplicados).
5. Resolver el evento, aplicar consecuencias (oxígeno, energía, salud…) y avanzar.
6. Confirmar o rechazar cada elección con `choice_result`.

Node solo garantiza quién es quién. Que un mensaje llegue **no** significa que sea válido para el juego.

## Arquitectura propuesta

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
- **`Events`** (`game/Scripts/events.gd`) ya existe y tiene `mobile_client_connected`. Añadid ahí las señales de red nuevas para mantener el patrón del proyecto.
- La lógica de eventos va en su propio script/autoload (`EventManager`), sin depender de `Net` directamente: recibe señales y llama a `Net.send_view(...)`.

### Señales sugeridas para `events.gd`

```gdscript
# --- Network (Node backend) ---
signal net_connected
signal net_disconnected
signal room_created(code: String)
signal lobby_updated(players: Array, status: String)   # lobby_state
signal game_started(players: Array)
signal player_choice_received(player_id: String, role: String, action_id: String, event_id: String, option_id: String)
signal room_closed(reason: String)
signal net_error(code: String, request_type: String)
```

## Conexión

### Dirección del servidor

La URL se construye desde el sitio que sirvió la página. **Nunca** una IP fija.

```gdscript
func _server_url() -> String:
	if OS.has_feature("web"):
		var proto: String = JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'")
		var host: String = JavaScriptBridge.eval("location.host")
		return "%s://%s/ws" % [proto, host]
	return "ws://localhost:3000/ws"   # solo para probar desde el editor con el backend en local
```

> En el editor (no web) no hay `location`; apuntad al backend local (`npm run dev` en `backend/`, puerto 3000). Para probar la integración completa, exportad a web y servid con Docker.

### Autoload `Net` (esqueleto)

```gdscript
extends Node
# game/Scripts/net.gd  → Proyecto > Ajustes > Autoload, nombre "Net"

var _ws := WebSocketPeer.new()
var _was_open := false
var room_code := ""
var players: Array = []            # último lobby_state.players

func connect_to_server() -> void:
	var err := _ws.connect_to_url(_server_url())
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

- Usad `location.origin` como base **solo si no es `localhost`/`127.0.0.1`**: esos nombres no sirven a los móviles. Si el anfitrión abrió el juego por `localhost`, mostrad un aviso y permitid escribir la IP de la LAN a mano (p. ej. `http://192.168.1.50`).
- Godot no trae generador de QR. Opciones: un addon/script GDScript de QR (que sea local, la demo no puede depender de Internet), o generarlo con una librería JS pequeña servida desde `dist/` y llamada mediante `JavaScriptBridge`. Elegid una y dejadla registrada en este documento.
- Mostrad siempre también el código en texto: es el plan B si falla el QR.

```gdscript
func _controller_url(code: String) -> String:
	var origin: String = JavaScriptBridge.eval("location.origin")
	return "%s/controller/?room=%s" % [origin, code]
```

## Eventos

### Modelo

```gdscript
class_name GameEvent   # un evento concreto de una partida
extends RefCounted

var id: String                      # "storm-01#1" → identifica ESTA aparición (ver abajo)
var mode: String                    # "individual" | "vote"
var eligible_players: Array[String] # playerIds que pueden decidir
var options: Array[Dictionary]      # [{ "id": "shelter", "label": "…" }, …]
var decisions: Dictionary = {}      # playerId -> optionId (ya aceptadas)
var results: Dictionary = {}        # actionId -> { "accepted": bool, "reason": String }  (idempotencia)
var closed := false
```

### `eventId`: una aparición, no una plantilla

`eventId` debe ser **único por aparición** del evento en esa partida. Si "tormenta solar" puede salir dos veces, no uséis `storm-01` las dos: usad `storm-01#1`, `storm-01#2` (o un contador global). Así un `choose` rezagado de la primera tormenta se reconoce como antiguo y se rechaza.

### Asignar jugadores según los roles presentes

Con 1–4 jugadores, un evento "para el ingeniero" no puede quedar sin destinatario:

- Construid `eligible_players` desde la lista de `game_started`, no desde una lista fija de cuatro roles.
- Si el rol destinatario no existe, elegid un sustituto determinista (p. ej. el `generalist`, o el primer jugador conectado) o abrid el evento como `vote` entre los presentes. Documentad la regla en el propio evento.
- Los jugadores **no elegibles** reciben igualmente una vista (`waiting` o informativa) para no quedarse con la pantalla anterior.

### Abrir un evento

```gdscript
func open_event(ev: GameEvent) -> void:
	for p in Net.players:
		var pid: String = p["id"]
		if pid in ev.eligible_players:
			Net.send_view(pid, {
				"screen": "choice", "eventId": ev.id,
				"title": ev.title, "prompt": ev.prompt, "options": ev.options,
			})
		else:
			Net.send_view(pid, {"screen": "waiting", "title": "Esperando decisión de la tripulación"})
```

Cada jugador puede recibir **opciones distintas**: sencillamente enviadle un `options` propio.

### Validar un `choose`

Orden recomendado (se recorre al recibir `player_choice_received`):

```gdscript
func _on_choice(player_id: String, role: String, action_id: String, event_id: String, option_id: String) -> void:
	var ev := current_event

	# 1. Duplicado: mismo actionId → repetir la respuesta anterior SIN repetir efectos.
	#    Se busca en TODOS los eventos recientes, por si el reenvío llega tras cerrarse el evento.
	var previous := _find_previous_result(action_id)
	if previous:
		Net.send_result(player_id, action_id, previous.accepted, previous.reason)
		return

	# 2. Evento antiguo o ya cerrado.
	if ev == null or ev.id != event_id or ev.closed:
		return _reject(player_id, action_id, "event_closed")
	# 3. ¿Puede decidir este jugador?
	if player_id not in ev.eligible_players:
		return _reject(player_id, action_id, "not_eligible")
	# 4. ¿Existe la opción?
	if not ev.options.any(func(o): return o["id"] == option_id):
		return _reject(player_id, action_id, "invalid_option")
	# 5. La elección aceptada queda bloqueada.
	if ev.decisions.has(player_id):
		return _reject(player_id, action_id, "already_decided")

	# 6. Aceptar.
	ev.decisions[player_id] = option_id
	_remember(ev, action_id, true, "")
	Net.send_result(player_id, action_id, true)
	_try_resolve(ev)
```

Puntos clave:

- **Idempotencia**: guardad `actionId → resultado` y respondedlo igual las veces que haga falta. Una doble pulsación o un reenvío tras reconexión **no** puede aplicar la consecuencia dos veces. Los rechazos también se memorizan.
- Responded **siempre** con un `choice_result` para que Node pueda validar el flujo; el mando no lo recibe. Enviad después una nueva `controller_view` para mostrar el resultado, espera o siguiente pregunta.
- La identidad (`player_id`, `role`) viene de Node y es fiable; no la leáis del contenido que mande el móvil.
- `already_decided` con un **`actionId` distinto**: el jugador ya votó y pulsó otra cosa. Con el mismo `actionId` es un duplicado (paso 1) y no un error.

### Resolver

Cuando `_try_resolve` detecta que se cumple la regla:

| Modo | Condición típica | Resolución |
|---|---|---|
| `individual` | Decide el jugador asignado. | Se aplica su opción. |
| `vote` | Han votado todos los `eligible_players` **conectados** requeridos. | Opción más votada. |

**Empates (`vote`):** nueva votación **solo entre las opciones empatadas** (nuevo `eventId`, p. ej. `storm-01#1-desempate`). Si vuelve a empatar, **se sortea** entre las empatadas.

Al resolver:

1. `ev.closed = true`.
2. Aplicad las consecuencias a recursos (solo aquí, nunca en el momento de recibir el `choose`).
3. Enviad a cada jugador una vista `result` (o `waiting` hasta el siguiente evento).
4. Emitid señales de juego (`oxygen_level_changed`, etc.) para actualizar la UI.

### Jugadores ausentes

`lobby_updated` sigue llegando durante la partida con `connected` actualizado.

- Si falta un jugador **necesario**, **esperad**. No resolváis solos.
- Dad al anfitrión un botón explícito "Omitir ausentes" que cierre el evento con las decisiones recibidas.
- Cuando un jugador **reconecta**, Node le reenvía su última `controller_view`; no hace falta que Godot la reenvíe. Si el evento ya se resolvió mientras estaba fuera, su `lastView` será la vista antigua: enviadle la vista vigente (`result`/`waiting`) al ver que vuelve a `connected == true`.

### Fin de partida

`Net.finish_game()` cuando acabe la misión. Los mandos recibirán `room_closed` (`game_finished`). Mostrad antes los resultados en Godot: tras `finish_game` la sala deja de existir.

## Desconexiones

| Situación | Qué hace Godot |
|---|---|
| Se cae el WebSocket del propio anfitrión (`net_disconnected`) | La sala ya no existe en Node y los mandos han recibido `room_closed`. Mostrad un mensaje y ofreced volver al menú. No intentéis reconectar a la misma sala. |
| Recargar la pestaña del anfitrión | Equivale a lo anterior: partida nueva. |
| Se desconecta un móvil | Llega `lobby_updated` con `connected: false`. Mantened su rol y sus decisiones. |
| Reinicio del backend | Mismo caso que caída del anfitrión. |

## Exportación web

- Preset **Web** en `game/export_presets.cfg` → `../dist/game/index.html`. `thread_support=false`, así que **no hacen falta cabeceras COOP/COEP** y Nginx se mantiene simple.
- Godot 4 web **solo arranca en un contexto seguro** (HTTPS o `localhost`). Por eso el despliegue sirve todo por HTTPS y el WebSocket es `wss://` (lo deduce `_server_url()` de `location.protocol`). Ver [../deploy.md](../deploy.md).
- Exportad siempre a `dist/game/` antes de levantar Docker (`npm run docker:prod`).
- `JavaScriptBridge` y `OS.has_feature("web")` solo funcionan en la exportación web. Protegedlo con `OS.has_feature("web")` para poder seguir probando desde el editor.
- Todos los recursos (fuentes, audio, imágenes) deben ir dentro del `.pck`; la demo no puede depender de Internet. Ojo con la llamada a la API de NASA de `main.gd`: tiene que fallar con gracia si no hay conexión.

## Cómo probar

1. Desde la raíz: `npm run dev` (backend + mando). Fijaos en el puerto que imprime el backend. En esa terminal se ven todos los mensajes que pasan por el backend (`←` recibidos, `→` enviados), útil para ver qué manda Godot y qué le llega.
2. Lanzad el juego desde el editor apuntando a `ws://localhost:<puerto>/ws`.
3. Abrid el mando en el móvil (`http://<IP-del-PC>:5173/controller/?room=<código>`) o en otra pestaña del PC.
4. Sin móviles, también vale cualquier cliente WebSocket (p. ej. `npx wscat -c ws://localhost:<puerto>/ws`) enviando a mano `join_room`, `select_role` y `choose`.
## Checklist de Godot

- [ ] `Net` hace `poll()` cada frame y centraliza el socket.
- [ ] Lobby pintado desde `lobby_state` completo, con jugadores desconectados diferenciados.
- [ ] QR (o enlace) con dirección de LAN, nunca `localhost`; código visible también en texto.
- [ ] Cada evento tiene `eventId` único por aparición.
- [ ] Un evento nunca depende de un rol ausente.
- [ ] `actionId` repetido → misma respuesta, sin efectos duplicados.
- [ ] `choose` de un evento anterior → `event_closed`.
- [ ] Todo `choose` recibe un `choice_result`.
- [x] Empate → segunda votación → sorteo.
- [ ] Tras `net_disconnected` se ofrece volver al menú.
