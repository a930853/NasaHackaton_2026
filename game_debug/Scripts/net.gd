extends Node
## Net: único punto del proyecto que toca el WebSocket con el backend.
##
## Se registra como autoload con el nombre "Net" (Proyecto > Ajustes > Autoload).
## El resto del juego no conoce el socket: escucha las señales de aquí y llama a
## las funciones de envío (create_room(), send_view()…).
##
## Contrato de mensajes: docs/protocol.md. Guía para Godot: docs/godot/red.md.
## En game/ estas señales irían al bus `Events`; en este proyecto de depuración
## se emiten directamente desde Net para que todo quede en un solo fichero.

# --- Estado de la conexión ---
signal connected                      ## El socket se ha abierto.
signal disconnected                   ## Se ha cerrado un socket que estaba abierto.
signal connection_failed              ## No se llegó a abrir (backend apagado, URL mal…).

# --- Tráfico en bruto (para el log de depuración) ---
signal message_sent(text: String)
signal message_received(text: String)

# --- Mensajes del contrato ya interpretados ---
signal room_created(code: String)
signal lobby_updated(players: Array, status: String)
signal game_started(players: Array)
signal choice_received(player_id: String, role: String, action_id: String, event_id: String, option_id: String)
signal server_error(code: String, request_type: String)

## Dirección por defecto fuera del navegador (editor o ejecución sin ventana).
## `npm run dev` puede elegir otro puerto si el 3000 está ocupado: mira lo que imprime.
const DEFAULT_DESKTOP_URL := "ws://localhost:3000/ws"

## Si es true, cada mensaje se imprime también en la salida estándar.
## Útil al ejecutar sin ventana (`--headless`) para ver el tráfico en la terminal.
var print_messages := true

var room_code := ""          ## Código de la sala que creó esta conexión ("" si no hay).
var players: Array = []      ## Último `players` recibido (lobby_state o game_started).

var _ws: WebSocketPeer = null
var _was_open := false


# ---------------------------------------------------------------------------
# Conexión
# ---------------------------------------------------------------------------

## URL del WebSocket. En la exportación web se deduce de la página que la sirvió
## (nunca IPs fijas); fuera del navegador, la dirección local por defecto.
func default_url() -> String:
	if OS.has_feature("web"):
		var proto: String = JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'")
		var host: String = JavaScriptBridge.eval("location.host")
		return "%s://%s/ws" % [proto, host]
	return DEFAULT_DESKTOP_URL


func connect_to_server(url: String) -> void:
	if _ws != null:
		return  # ya hay una conexión abierta o abriéndose
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		push_warning("Net: no se pudo iniciar la conexión a %s (error %d)" % [url, err])
		connection_failed.emit()


## Cierra la conexión. Para el backend, que el anfitrión se vaya cierra la sala
## y los mandos reciben `room_closed`.
func close() -> void:
	if _ws != null:
		_ws.close()  # el cambio a CLOSED se detecta en _process


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


## Texto corto del estado, para mostrarlo en pantalla.
func state_name() -> String:
	if _ws == null:
		return "desconectado"
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING: return "conectando…"
		WebSocketPeer.STATE_OPEN: return "conectado"
		WebSocketPeer.STATE_CLOSING: return "cerrando…"
	return "desconectado"


func _process(_delta: float) -> void:
	if _ws == null:
		return

	# WebSocketPeer no funciona con señales: hay que llamar a poll() en cada
	# frame. Sin esto no se envía ni se recibe nada.
	_ws.poll()

	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				connected.emit()
			while _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			var had_opened := _was_open
			_ws = null
			_was_open = false
			room_code = ""
			players = []
			if had_opened:
				disconnected.emit()
			else:
				connection_failed.emit()


# ---------------------------------------------------------------------------
# Recepción
# ---------------------------------------------------------------------------

## Interpreta un mensaje del backend y emite la señal que le corresponde.
func _handle(text: String) -> void:
	if print_messages:
		print("← ", text)
	message_received.emit(text)

	# JSON.parse_string devuelve null si el texto no es JSON válido.
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("type"):
		push_warning("Net: mensaje sin formato válido: %s" % text)
		return

	match msg["type"]:
		"room_created":
			room_code = msg.get("code", "")
			room_created.emit(room_code)
		"lobby_state":
			# Es un estado COMPLETO: se sustituye la lista entera, no se mezcla.
			players = msg.get("players", [])
			lobby_updated.emit(players, msg.get("status", ""))
		"game_started":
			players = msg.get("players", [])
			game_started.emit(players)
		"choose":
			# playerId y role los añade Node desde la conexión: son fiables.
			# Todos los ids del contrato son String; no convertirlos a número.
			choice_received.emit(
				str(msg.get("playerId", "")), str(msg.get("role", "")),
				str(msg.get("actionId", "")), str(msg.get("eventId", "")),
				str(msg.get("optionId", "")))
		"error":
			server_error.emit(msg.get("code", ""), msg.get("requestType", ""))


# ---------------------------------------------------------------------------
# Envío: API para el resto del juego
# ---------------------------------------------------------------------------

func create_room() -> void:
	_send({"type": "create_room"})


func start_game() -> void:
	_send({"type": "start_game"})


## Termina la partida: el backend avisa a los mandos (`room_closed`) y borra la
## sala. Esta conexión ya no sirve para crear otra sala, así que se cierra; para
## una partida nueva hay que volver a conectar.
func finish_game() -> void:
	_send({"type": "finish_game"})
	close()


## Envía a un jugador lo que debe mostrar su móvil (screen: choice | waiting | result).
func send_view(player_id: String, view: Dictionary) -> void:
	_send({"type": "controller_view", "playerId": player_id, "view": view})


## Responde a un `choose`. Hay que responder SIEMPRE, aceptado o no.
func send_result(player_id: String, action_id: String, accepted: bool, reason := "") -> void:
	var msg := {"type": "choice_result", "playerId": player_id, "actionId": action_id, "accepted": accepted}
	if not accepted:
		msg["reason"] = reason
	_send(msg)


func _send(msg: Dictionary) -> void:
	if not is_open():
		push_warning("Net: sin conexión, no se envía %s" % msg.get("type"))
		return
	var text := JSON.stringify(msg)
	if print_messages:
		print("→ ", text)
	_ws.send_text(text)
	message_sent.emit(text)
