extends Node
## Autoload "Net": único punto del juego que toca el WebSocket con el backend.
##
## El resto del juego no conoce el socket: escucha las señales de red del bus `Events`
## (net_connected, room_created, lobby_updated, game_started, player_choice_received…)
## y llama a las funciones de envío de aquí (create_room(), send_view(), send_result()…).
##
## Contrato de mensajes: docs/protocol.md. Guía para Godot: docs/godot/red.md.
## Quien traduce entre el juego (TurnManager) y los móviles es PhoneBridge.

## Dirección por defecto fuera del navegador (editor o ejecución sin ventana).
## `npm run dev` puede elegir otro puerto si el 3000 está ocupado: mira lo que imprime.
const DEFAULT_DESKTOP_URL: String = "ws://localhost:3000/ws"
## Si el juego se lanza con `--ws-url=ws://localhost:3100/ws` (o `NASA_WS_URL`), se usa esa dirección.
const URL_ARGUMENT: String = "--ws-url="
const URL_ENVIRONMENT: String = "NASA_WS_URL"
## Si el servidor no contesta en este tiempo, se da por fallida la conexión (para poder avisar al jugador).
const CONNECT_TIMEOUT_SECONDS: float = 4.0

## Si es true, cada mensaje se imprime en la salida estándar (útil con el plugin de Godot o `--headless`).
var print_messages: bool = OS.is_debug_build()

var room_code: String = ""          ## Código de la sala que creó esta conexión ("" si no hay).
var players: Array = []             ## Último `players` recibido (lobby_state o game_started).
var room_status: String = ""        ## lobby | playing | finished

var _ws: WebSocketPeer = null
var _was_open: bool = false
var _connect_started_msec: int = 0


# ---------------------------------------------------------------------------
# Conexión
# ---------------------------------------------------------------------------

## URL del WebSocket. En la exportación web se deduce de la página que la sirvió
## (nunca IPs fijas); fuera del navegador, la que se pase por argumento o entorno,
## y si no, la dirección local por defecto.
func default_url() -> String:
	if OS.has_feature("web"):
		var proto: String = str(JavaScriptBridge.eval("location.protocol === 'https:' ? 'wss' : 'ws'"))
		var host: String = str(JavaScriptBridge.eval("location.host"))
		return "%s://%s/ws" % [proto, host]
	for argument in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if argument.begins_with(URL_ARGUMENT):
			return argument.trim_prefix(URL_ARGUMENT)
	var from_environment: String = OS.get_environment(URL_ENVIRONMENT)
	if not from_environment.is_empty():
		return from_environment
	return DEFAULT_DESKTOP_URL


## Dirección de la que cuelga el mando para los móviles (la que va en el QR o se escribe a mano).
## En web es el origen de la página; en el editor, el servidor de desarrollo del mando (Vite).
## Con `localhost` los móviles no podrán entrar: `controller_url_is_local()` lo avisa.
func controller_base_url() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("location.origin"))
	return "http://localhost:5173"


func controller_url_is_local() -> bool:
	var base: String = controller_base_url()
	return base.contains("localhost") or base.contains("127.0.0.1")


func controller_url(code: String) -> String:
	return "%s/controller/?room=%s" % [controller_base_url(), code]


func connect_to_server(url: String = "") -> void:
	if _ws != null:
		return  # ya hay una conexión abierta o abriéndose
	if url.is_empty():
		url = default_url()
	_ws = WebSocketPeer.new()
	_connect_started_msec = Time.get_ticks_msec()
	var err: int = _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		push_warning("Net: no se pudo iniciar la conexión a %s (error %d)" % [url, err])
		Events.net_connection_failed.emit()


## Cierra la conexión. Para el backend, que el anfitrión se vaya cierra la sala
## y los mandos reciben `room_closed`.
func close() -> void:
	if _ws != null:
		_ws.close()  # el cambio a CLOSED se detecta en _process


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func is_connecting() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING


func _process(_delta: float) -> void:
	if _ws == null:
		return

	# WebSocketPeer no funciona con señales: hay que llamar a poll() en cada
	# frame. Sin esto no se envía ni se recibe nada.
	_ws.poll()

	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if float(Time.get_ticks_msec() - _connect_started_msec) / 1000.0 > CONNECT_TIMEOUT_SECONDS:
				push_warning("Net: el servidor no contesta (tiempo agotado).")
				_ws.close()
				_ws = null
				Events.net_connection_failed.emit()
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				Events.net_connected.emit()
			while _ws != null and _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			var had_opened: bool = _was_open
			_ws = null
			_was_open = false
			room_code = ""
			room_status = ""
			players = []
			if had_opened:
				Events.net_disconnected.emit()
			else:
				Events.net_connection_failed.emit()


# ---------------------------------------------------------------------------
# Recepción
# ---------------------------------------------------------------------------

## Interpreta un mensaje del backend y emite la señal que le corresponde.
func _handle(text: String) -> void:
	if print_messages:
		print("Net <- ", text)

	# JSON.parse_string devuelve null si el texto no es JSON válido.
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("type"):
		push_warning("Net: mensaje sin formato válido: %s" % text)
		return

	match msg["type"]:
		"room_created":
			room_code = str(msg.get("code", ""))
			Events.room_created.emit(room_code)
		"lobby_state":
			# Es un estado COMPLETO: se sustituye la lista entera, no se mezcla.
			players = msg.get("players", [])
			room_status = str(msg.get("status", ""))
			Events.lobby_updated.emit(players, room_status)
		"game_started":
			players = msg.get("players", [])
			room_status = "playing"
			Events.game_started.emit(players)
		"choose":
			# playerId y role los añade Node desde la conexión: son fiables.
			# Todos los ids del contrato son String; no convertirlos a número.
			Events.player_choice_received.emit(
				str(msg.get("playerId", "")), str(msg.get("role", "")),
				str(msg.get("actionId", "")), str(msg.get("eventId", "")),
				str(msg.get("optionId", "")))
		"continue":
			Events.player_continue_received.emit(
				str(msg.get("playerId", "")), str(msg.get("role", "")), str(msg.get("actionId", "")))
		"room_closed":
			Events.room_closed.emit(str(msg.get("reason", "")))
		"error":
			push_warning("Net: el backend rechazó '%s': %s" % [msg.get("requestType", "?"), msg.get("code", "?")])
			Events.net_error.emit(str(msg.get("code", "")), str(msg.get("requestType", "")))


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
func send_result(player_id: String, action_id: String, accepted: bool, reason: String = "") -> void:
	var msg: Dictionary = {"type": "choice_result", "playerId": player_id, "actionId": action_id, "accepted": accepted}
	if not accepted:
		msg["reason"] = reason
	_send(msg)


func _send(msg: Dictionary) -> void:
	if not is_open():
		push_warning("Net: sin conexión, no se envía %s" % msg.get("type"))
		return
	var text: String = JSON.stringify(msg)
	if print_messages:
		print("Net -> ", text)
	_ws.send_text(text)
