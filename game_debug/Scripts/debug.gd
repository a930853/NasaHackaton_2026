extends Control
## Pantalla de depuración de la conexión Godot ↔ backend ↔ móviles.
##
## Hace de anfitrión mínimo: conecta, crea la sala, muestra el lobby, inicia la
## partida y lanza una votación de prueba ("elige un color"). Lo que elige un
## móvil cambia el texto grande de esta pantalla (primer hito del proyecto).
## A la derecha se ven todos los mensajes en bruto.
##
## Piezas:
##   Net        (net.gd)          el WebSocket y el contrato de mensajes
##   DemoRound  (demo_round.gd)   validación de cada `choose`
##   MessageLog (message_log.gd)  panel de mensajes
##   este script                  construye la interfaz y une lo anterior
##
## Opciones al ejecutar (van detrás de `--`):
##   --server=ws://localhost:8787/ws   dirección del backend
##   --controller-port=5174            puerto del mando (Vite) para la dirección del móvil
##   --auto                            conecta y crea la sala al arrancar
##   --autostart                       inicia la partida y lanza la pregunta en
##                                     cuanto todos los jugadores tienen rol
## Ejemplo sin ventana:
##   godot --headless --path game_debug -- --server=ws://localhost:8787/ws --auto --autostart

const ROLE_NAMES := {
	"engineer": "Ingeniero",
	"biologist": "Bióloga",
	"doctor": "Médico",
	"generalist": "Polivalente",
}

const DEMO_OPTIONS := [
	{"id": "red", "label": "Rojo"},
	{"id": "green", "label": "Verde"},
	{"id": "blue", "label": "Azul"},
]
const OPTION_COLORS := {"red": Color("e5484d"), "green": Color("30a46c"), "blue": Color("3e63dd")}

## Texto que ve el móvil cuando se rechaza su elección.
const REJECT_TEXTS := {
	"event_closed": "Esa pregunta ya se cerró.",
	"not_eligible": "En esta pregunta no te toca decidir.",
	"invalid_option": "Esa opción no existe.",
	"already_decided": "Ya habías elegido.",
}

var _round := DemoRound.new()
var _status := ""          # status del último lobby_state: lobby | playing | finished
var _auto_create := false
var _auto_start := false
var _controller_port := "5173"   # puerto de Vite; npm run dev lo imprime

# Controles (se crean en _build_ui)
var _url_edit: LineEdit
var _connect_button: Button
var _state_label: Label
var _create_button: Button
var _start_button: Button
var _ask_button: Button
var _finish_button: Button
var _code_label: Label
var _join_label: Label
var _players_label: RichTextLabel
var _choice_label: Label
var _log: MessageLog


func _ready() -> void:
	_build_ui()
	_connect_net_signals()

	var args := _user_args()
	_url_edit.text = args.get("server", Net.default_url())
	_auto_create = args.has("auto")
	_auto_start = args.has("autostart")
	_controller_port = args.get("controller-port", _controller_port)

	if not OS.has_feature("web"):
		_log.add_note("Arranca el backend con «npm run dev» (raíz del repo) y pulsa Conectar.")
	if _auto_create:
		_on_connect_pressed()


func _process(_delta: float) -> void:
	_refresh_controls()  # barato: solo habilita/deshabilita botones


# ---------------------------------------------------------------------------
# Señales de Net
# ---------------------------------------------------------------------------

func _connect_net_signals() -> void:
	Net.message_sent.connect(_log.add_sent)
	Net.message_received.connect(_log.add_received)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.room_created.connect(_on_room_created)
	Net.lobby_updated.connect(_on_lobby_updated)
	Net.game_started.connect(_on_game_started)
	Net.choice_received.connect(_on_choice_received)
	Net.server_error.connect(_on_server_error)


func _on_connected() -> void:
	_log.add_note("Conectado a %s" % _url_edit.text)
	if _auto_create:
		Net.create_room()


func _on_disconnected() -> void:
	_log.add_note("Desconectado. La sala ya no existe; vuelve a conectar para crear otra.")
	_reset_room()


func _on_connection_failed() -> void:
	_log.add_note("No se pudo conectar a %s. ¿Está el backend arrancado? ¿Es el puerto que imprime «npm run dev»?" % _url_edit.text, true)
	_reset_room()


func _on_room_created(code: String) -> void:
	_code_label.text = code
	_join_label.text = "Abre el mando en el móvil (la IP de tu Wi-Fi):\n%s" % _controller_url(code)
	_log.add_note("Sala %s creada. Abre el mando en el móvil con esa dirección." % code)


func _on_lobby_updated(players: Array, status: String) -> void:
	_status = status
	_render_players(players)
	if _auto_start and status == "lobby" and _can_start(players):
		Net.start_game()


func _on_game_started(players: Array) -> void:
	_status = "playing"
	_render_players(players)
	_log.add_note("Partida iniciada con %d jugador(es)." % players.size())
	if _auto_start:
		_ask_question()


func _on_server_error(code: String, request_type: String) -> void:
	_log.add_note("El backend rechazó «%s»: %s" % [request_type, code], true)


# ---------------------------------------------------------------------------
# La votación de prueba
# ---------------------------------------------------------------------------

## Abre una ronda y envía la pregunta a todos los jugadores.
func _ask_question() -> void:
	var ids: Array[String] = []
	for p in Net.players:
		ids.append(str(p["id"]))
	var event_id := _round.open(ids, DEMO_OPTIONS)

	for pid in ids:
		Net.send_view(pid, {
			"screen": "choice",
			"eventId": event_id,
			"title": "Prueba de conexión",
			"prompt": "Elige un color: cambiará el texto de la pantalla principal.",
			"options": DEMO_OPTIONS,
		})
	_set_choice_text("Esperando elecciones (%s)…" % event_id, Color.WHITE)


## Un móvil ha elegido. Se valida, se responde SIEMPRE con choice_result y se
## envía al móvil su siguiente vista (el mando no recibe choice_result).
func _on_choice_received(player_id: String, role: String, action_id: String, event_id: String, option_id: String) -> void:
	var verdict := _round.judge(player_id, action_id, event_id, option_id)
	Net.send_result(player_id, action_id, verdict["accepted"], verdict["reason"])

	if verdict["duplicate"]:
		_log.add_note("actionId %s repetido: misma respuesta, sin repetir efectos." % action_id)

	if not verdict["accepted"]:
		Net.send_view(player_id, {
			"screen": "result",
			"title": "Elección rechazada",
			"text": REJECT_TEXTS.get(verdict["reason"], verdict["reason"]),
		})
		return

	var label := _round.option_label(option_id)
	Net.send_view(player_id, {
		"screen": "result",
		"title": "Elección recibida",
		"text": "Has elegido %s. Mira la pantalla principal." % label,
	})

	if verdict["duplicate"]:
		return  # ya se aplicó la primera vez

	# El "efecto" de la elección: cambiar el texto grande.
	_set_choice_text("%s (%s) ha elegido: %s" % [_player_name(player_id), _role_name(role), label],
		OPTION_COLORS.get(option_id, Color.WHITE))

	if _round.everyone_decided():
		_round.close()
		_log.add_note("Todos han elegido: ronda %s cerrada." % _round.event_id)


# ---------------------------------------------------------------------------
# Botones
# ---------------------------------------------------------------------------

func _on_connect_pressed() -> void:
	if Net.state_name() == "desconectado":
		Net.connect_to_server(_url_edit.text.strip_edges())
	else:
		Net.close()


func _on_finish_pressed() -> void:
	Net.finish_game()   # también cierra la conexión (ver net.gd)
	_set_choice_text("Partida terminada", Color.WHITE)


func _refresh_controls() -> void:
	var state := Net.state_name()
	var open := Net.is_open()
	_state_label.text = state
	_connect_button.text = "Conectar" if state == "desconectado" else "Desconectar"
	_url_edit.editable = state == "desconectado"
	_create_button.disabled = not open or Net.room_code != ""
	_start_button.disabled = not (open and _status == "lobby" and _can_start(Net.players))
	_ask_button.disabled = not (open and _status == "playing")
	_finish_button.disabled = not (open and _status == "playing")


# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

## Se puede iniciar con 1–4 jugadores si todos tienen rol (lo mismo que exige Node).
func _can_start(players: Array) -> bool:
	return not players.is_empty() and players.all(func(p: Dictionary) -> bool: return p.get("role") != null)


func _reset_room() -> void:
	_status = ""
	_round.close()
	_code_label.text = "----"
	_join_label.text = ""
	_render_players([])


func _render_players(players: Array) -> void:
	if players.is_empty():
		_players_label.text = "[color=#808080]Sin jugadores[/color]"
		return
	var lines: PackedStringArray = []
	for p in players:
		var role: Variant = p.get("role")
		var role_text := _role_name(role) if role != null else "[color=#e0a040]sin rol[/color]"
		var dot := "[color=#30a46c]●[/color]" if p.get("connected", false) else "[color=#808080]○ desconectado[/color]"
		lines.append("%s  %s  %s  %s" % [p["id"], p["name"], role_text, dot])
	_players_label.text = "\n".join(lines)


func _player_name(player_id: String) -> String:
	for p in Net.players:
		if p["id"] == player_id:
			return p["name"]
	return player_id


func _role_name(role: Variant) -> String:
	return ROLE_NAMES.get(role, str(role))


func _set_choice_text(text: String, color: Color) -> void:
	_choice_label.text = text
	_choice_label.add_theme_color_override("font_color", color)


## Dirección(es) del mando para escribirla en el móvil.
## En web se usa la página actual. Fuera del navegador no se sabe cuál de las IP
## del PC es la de la Wi-Fi (puede haber VirtualBox, WSL, VPN…), así que se
## listan todas las privadas con el puerto de Vite. Nunca localhost: el móvil no lo ve.
func _controller_url(code: String) -> String:
	if OS.has_feature("web"):
		var origin: String = JavaScriptBridge.eval("location.origin")
		return "%s/controller/?room=%s" % [origin, code]
	var urls: PackedStringArray = []
	for ip in _lan_ips():
		urls.append("http://%s:%s/controller/?room=%s" % [ip, _controller_port, code])
	if urls.is_empty():
		urls.append("http://<IP-del-PC>:%s/controller/?room=%s" % [_controller_port, code])
	return "\n".join(urls)


## En web: ¿se abrió la página con localhost? (Fuera del navegador, no aplica.)
func _opened_with_localhost() -> bool:
	if not OS.has_feature("web"):
		return false
	var host: String = JavaScriptBridge.eval("location.hostname")
	return host == "localhost" or host == "127.0.0.1" or host == "[::1]"


func _lan_ips() -> PackedStringArray:
	var ips: PackedStringArray = []
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			ips.append(address)
	return ips


## Convierte "--server=x --auto" (lo que va tras `--`) en {"server": "x", "auto": ""}.
func _user_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result


# ---------------------------------------------------------------------------
# Interfaz (se monta en código para que todo se lea en un solo sitio)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("14161c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Aviso si la pantalla se abrió con localhost: funciona, pero la dirección
	# del mando que se enseña no les sirve a los móviles.
	if _opened_with_localhost():
		var warning := _make_label("Has abierto la pantalla con «localhost»: los móviles no podrán entrar con la dirección que se muestra. Ábrela con la IP del PC (https://<IP>/game/). Para probar en este mismo PC, sí sirve.", 18)
		warning.add_theme_color_override("font_color", Color("ff7a7a"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(warning)

	# Fila 1: servidor y estado
	var server_row := HBoxContainer.new()
	root.add_child(server_row)
	server_row.add_child(_make_label("Servidor"))
	_url_edit = LineEdit.new()
	_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(_url_edit)
	_connect_button = _make_button("Conectar", _on_connect_pressed)
	server_row.add_child(_connect_button)
	_state_label = _make_label("desconectado")
	_state_label.custom_minimum_size.x = 110
	server_row.add_child(_state_label)

	# Fila 2: acciones del anfitrión
	var actions := HBoxContainer.new()
	root.add_child(actions)
	_create_button = _make_button("Crear sala", Net.create_room)
	_start_button = _make_button("Iniciar partida", Net.start_game)
	_ask_button = _make_button("Enviar pregunta", _ask_question)
	_finish_button = _make_button("Terminar partida", _on_finish_pressed)
	for button in [_create_button, _start_button, _ask_button, _finish_button]:
		actions.add_child(button)

	# Zona principal: izquierda (sala, jugadores, elección) | derecha (log)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	left.add_child(_make_label("Código de sala"))
	_code_label = _make_label("----", 56)
	left.add_child(_code_label)
	_join_label = _make_label("")
	_join_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	left.add_child(_join_label)

	left.add_child(_make_label("Jugadores"))
	_players_label = RichTextLabel.new()
	_players_label.bbcode_enabled = true
	_players_label.fit_content = true
	left.add_child(_players_label)
	_render_players([])

	left.add_child(_make_label("Última elección"))
	_choice_label = _make_label("—", 28)
	_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_choice_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var log_header := HBoxContainer.new()
	right.add_child(log_header)
	var log_title := _make_label("Mensajes  (→ enviado · ← recibido)")
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_header.add_child(log_title)
	_log = MessageLog.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_header.add_child(_make_button("Limpiar", func() -> void: _log.clear()))
	right.add_child(_log)


func _make_label(text: String, font_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	return button
