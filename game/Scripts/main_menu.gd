extends Control
## Menú principal y lobby. El lobby se conecta con el backend (autoload Net): crea una sala,
## enseña el código y la dirección del mando para los móviles, y lista a los jugadores que entran
## con su rol. "Start expedition" arranca la partida cuando todos tienen rol.
## Sin backend se puede jugar igualmente en esta pantalla ("Play on this screen only").

const MEMBERS_TOP_SPACE: float = 48.0     # hueco para el título "Members"
const OFFLINE_COLOR: Color = Color(0.55, 0.55, 0.6)

@onready var mainButtons: Control = $MenuButtons
@onready var lobby: Control = $Lobby
@onready var options: Control = $OptionsPanel
@onready var members_box: VBoxContainer = $Lobby/Panel/MembersPanel/VBoxContainer
@onready var info_label: RichTextLabel = $Lobby/Panel/RichTextLabel
@onready var start_expedition_button: Button = $Lobby/Panel/StartExpButton

var _local_button: Button
var _starting: bool = false


func _ready() -> void:
	lobby.visible = false
	mainButtons.visible = true
	info_label.bbcode_enabled = true

	# Volver al menú cierra la sala anterior: cada partida con móviles usa una sala nueva.
	PhoneBridge.end_session()

	_local_button = Button.new()
	_local_button.text = "Play on this screen only"
	_local_button.set_anchors_preset(Control.PRESET_CENTER)
	_local_button.offset_left = 60.0
	_local_button.offset_right = 312.0
	_local_button.offset_top = 164.0
	_local_button.offset_bottom = 218.0
	_local_button.pressed.connect(_on_local_pressed)
	$Lobby/Panel.add_child(_local_button)

	Events.net_connected.connect(_on_net_connected)
	Events.net_connection_failed.connect(_on_connection_failed)
	Events.net_disconnected.connect(_on_net_disconnected)
	Events.room_created.connect(_on_room_created)
	Events.lobby_updated.connect(_on_lobby_updated)
	Events.game_started.connect(_on_game_started)
	Events.net_error.connect(_on_net_error)


func _on_start_button_pressed() -> void:
	lobby.visible = true
	mainButtons.visible = false
	_show_info("Connecting to the game server...")
	_refresh_members([])
	_update_start_button()
	if Net.is_open():
		Net.create_room()
	else:
		Net.connect_to_server()


## "Start expedition": pide al backend que empiece la partida. La escena cambia al recibir `game_started`.
func _on_start_exp_button_pressed() -> void:
	if _starting:
		return
	if Net.is_open() and not Net.room_code.is_empty():
		_starting = true
		start_expedition_button.disabled = true
		Net.start_game()


func _on_local_pressed() -> void:
	if _starting:
		return
	_starting = true
	PhoneBridge.use_local_only()
	_go_to_intro()


func _on_options_button_pressed() -> void:
	options.visible = true


# ---------------------------------------------------------------- Red

func _on_net_connected() -> void:
	if lobby.visible:
		Net.create_room()


func _on_connection_failed() -> void:
	if not lobby.visible:
		return
	_show_info("[color=#ff9a7a]Could not reach the game server.[/color]\nNo problem: you can still play on this screen only (use the debug phone panel to choose options).")
	_refresh_members([])
	_update_start_button()


func _on_net_disconnected() -> void:
	if not lobby.visible or _starting:
		return
	_show_info("[color=#ff9a7a]The connection to the game server was lost.[/color]\nGo back and press Start Game again, or play on this screen only.")
	_refresh_members([])
	_update_start_button()


func _on_room_created(code: String) -> void:
	_show_room_info(code)
	_update_start_button()


func _on_lobby_updated(players: Array, _status: String) -> void:
	_refresh_members(players)
	_update_start_button()


func _on_game_started(_players: Array) -> void:
	_go_to_intro()


func _on_net_error(code: String, _request_type: String) -> void:
	if not lobby.visible:
		return
	_starting = false
	var text: String = {
		"players_without_role": "Every player must pick a role on their phone first.",
		"no_players": "Wait for at least one player to join.",
	}.get(code, "The server said: %s" % code)
	_show_room_info(Net.room_code, "[color=#ffd27a]%s[/color]" % text)
	_update_start_button()


func _go_to_intro() -> void:
	Events.scene_change_requested.emit("intro")


# ---------------------------------------------------------------- Pantalla del lobby

func _show_info(bbcode: String) -> void:
	info_label.text = bbcode


func _show_room_info(code: String, note: String = "") -> void:
	var lines: Array[String] = []
	lines.append("[b]Room code:[/b]  [font_size=44][b]%s[/b][/font_size]" % code)
	lines.append("")
	lines.append("[b]How to join (on a phone):[/b]")
	lines.append("1. Connect the phone to the same Wi-Fi.")
	lines.append("2. Open  [b]%s[/b]" % Net.controller_url(code))
	lines.append("    (or open the home page and type the code).")
	lines.append("3. Pick a role. When everybody is ready, press Start expedition.")
	if Net.controller_url_is_local():
		lines.append("")
		lines.append("[color=#ffd27a]Heads up: this address says \"localhost\", so phones cannot use it. Open the game with the computer's network address.[/color]")
	if not note.is_empty():
		lines.append("")
		lines.append(note)
	_show_info("\n".join(PackedStringArray(lines)))


func _refresh_members(players: Array) -> void:
	for child in members_box.get_children():
		members_box.remove_child(child)
		child.queue_free()

	var space := Control.new()
	space.custom_minimum_size = Vector2(0.0, MEMBERS_TOP_SPACE)
	members_box.add_child(space)

	if players.is_empty():
		members_box.add_child(_member_label("Waiting for players...", OFFLINE_COLOR))
		return
	for player in players:
		var role: Variant = player.get("role")
		var role_text: String = "choosing a role..." if role == null else str(GameState.ROLE_NAMES.get(str(role), role))
		var color: Color = CrewAvatar.ROLE_ALBEDO.get(str(role), Color.WHITE) if role != null else Color.WHITE
		var connected: bool = bool(player.get("connected", true))
		var text: String = "%s  -  %s%s" % [str(player.get("name", "?")), role_text, "" if connected else "  (disconnected)"]
		members_box.add_child(_member_label(text, color if connected else OFFLINE_COLOR))


func _member_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## "Start expedition" solo se activa con sala creada, al menos un jugador y todos con rol.
func _update_start_button() -> void:
	var ready_to_start: bool = Net.is_open() and not Net.room_code.is_empty() and not Net.players.is_empty()
	for player in Net.players:
		if player.get("role") == null:
			ready_to_start = false
	start_expedition_button.disabled = _starting or not ready_to_start
	if Net.players.is_empty() or ready_to_start:
		start_expedition_button.tooltip_text = ""
	else:
		start_expedition_button.tooltip_text = "Every player must pick a role first."
