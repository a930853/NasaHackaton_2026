extends Control
## Menú principal. "Start Game" pregunta cómo jugar:
##   Play solo         -> una sola pantalla, las opciones se eligen con el ratón (sin móviles ni red).
##   Play multiplayer  -> lobby conectado con el backend (autoload Net): crea una sala, enseña el código
##                        y la dirección del mando, y lista a los jugadores que entran con su rol.
##                        "Start expedition" arranca la partida cuando todos tienen rol.

const MEMBERS_TOP_SPACE: float = 48.0     # hueco para el título "Members"
const OFFLINE_COLOR: Color = Color(0.55, 0.55, 0.6)
const MODE_TITLE_FONT_SIZE: int = 36       # la pregunta de «jugar solo o multijugador» (el título del juego usa 55)
const MODE_TITLE_WAVE: String = "20.0"
const MODE_BOX_WIDTH: float = 580.0        # ancho de la pregunta (se parte en dos líneas)
const MODE_BUTTON_WIDTH: float = 440.0
const LOBBY_FONT_SIZE: int = 16           # texto de los botones del lobby (más estrecho que el del menú)
const QR_SIZE: float = 186.0              # lado del QR del lobby en pantalla
const CREDITS_WIDTH: float = 900.0
const CREDITS_HEIGHT: float = 620.0

@onready var mainButtons: Control = $MenuButtons
@onready var lobby: Control = $Lobby
@onready var options: Control = $OptionsPanel
@onready var members_box: VBoxContainer = $Lobby/Panel/MembersPanel/VBoxContainer
@onready var info_label: RichTextLabel = $Lobby/Panel/RichTextLabel
@onready var start_expedition_button: Button = $Lobby/Panel/StartExpButton

var _mode_box: VBoxContainer     # "How do you want to play?": solo o multijugador
var _local_button: Button        # en el lobby: pasar a jugar solo (p. ej. si no hay servidor)
var _back_button: Button         # en el lobby: volver a la elección de modo
var _qr_box: VBoxContainer       # en el lobby: QR con la dirección del mando para los móviles
var _qr_rect: TextureRect
var _credits: Control
var _starting: bool = false


func _ready() -> void:
	lobby.visible = false
	mainButtons.visible = true
	info_label.bbcode_enabled = true

	# Volver al menú cierra la sala anterior: cada partida con móviles usa una sala nueva.
	PhoneBridge.end_session()

	_build_mode_box()
	_build_qr_box()
	_build_credits()

	# Botones del lobby: todos con el estilo azul del menú (MenuStyle).
	MenuStyle.apply(start_expedition_button, LOBBY_FONT_SIZE)
	MenuStyle.apply($Lobby/Button, LOBBY_FONT_SIZE)

	# "Start expedition" pegado al borde derecho del panel; Back y "Play solo instead" junto a "Options",
	# en la fila de abajo a la izquierda (los botones azules son grandes y no caben en una sola fila).
	start_expedition_button.offset_left = 232.0
	start_expedition_button.offset_right = 528.0
	start_expedition_button.offset_top = 164.0
	start_expedition_button.offset_bottom = 228.0

	_back_button = _make_lobby_button("Back", 245.0, 355.0)
	_back_button.pressed.connect(_on_lobby_back_pressed)
	_local_button = _make_lobby_button("Play solo instead", 367.0, 679.0)
	_local_button.pressed.connect(_on_local_pressed)

	Events.net_connected.connect(_on_net_connected)
	Events.net_connection_failed.connect(_on_connection_failed)
	Events.net_disconnected.connect(_on_net_disconnected)
	Events.room_created.connect(_on_room_created)
	Events.lobby_updated.connect(_on_lobby_updated)
	Events.game_started.connect(_on_game_started)
	Events.net_error.connect(_on_net_error)


## "Start Game": primero se elige el modo.
func _on_start_button_pressed() -> void:
	mainButtons.visible = false
	lobby.visible = false
	_mode_box.visible = true
	


func _build_mode_box() -> void:
	_mode_box = VBoxContainer.new()
	_mode_box.set_anchors_preset(Control.PRESET_CENTER)
	_mode_box.offset_left = -MODE_BOX_WIDTH / 2.0
	_mode_box.offset_right = MODE_BOX_WIDTH / 2.0
	_mode_box.offset_top = -165.0
	_mode_box.offset_bottom = 165.0
	_mode_box.add_theme_constant_override("separation", 12)
	_mode_box.visible = false
	add_child(_mode_box)

	# La pregunta, con la misma estética que el título del juego: su fuente y su efecto de ola.
	var game_title: RichTextLabel = $Tittle
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("normal_font", game_title.get_theme_font("normal_font"))
	title.add_theme_font_size_override("normal_font_size", MODE_TITLE_FONT_SIZE)
	title.text = "[wave amp=%s freq=2.0 connected=1]How do you want to play?[/wave]" % MODE_TITLE_WAVE
	_mode_box.add_child(title)

	var solo := _mode_button("Play solo", "One player. You choose every option with the mouse. No phone needed.")
	solo.pressed.connect(_on_solo_pressed)
	var multi_button := _mode_button("Play multiplayer", "Up to 4 players. Each one joins with a phone and the crew votes.")
	multi_button.pressed.connect(_on_multiplayer_pressed)
	var back := _mode_button("Back", "")
	back.pressed.connect(_on_mode_back_pressed)
	_mode_box.add_child(solo)
	_mode_box.add_child(multi_button)
	_mode_box.add_child(back)


## Botón azul anclado abajo a la izquierda de la pantalla del lobby, en la misma fila que "Options".
func _make_lobby_button(text: String, left: float, right: float) -> Button:
	var button := Button.new()
	button.text = text
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = left
	button.offset_right = right
	button.offset_top = -80.0
	button.offset_bottom = -16.0
	MenuStyle.apply(button, LOBBY_FONT_SIZE)
	$Lobby.add_child(button)
	return button


func _mode_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	MenuStyle.apply(button)
	button.custom_minimum_size.x = MODE_BUTTON_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # la pregunta es más ancha que los botones
	return button


func _on_mode_back_pressed() -> void:
	_mode_box.visible = false
	mainButtons.visible = true


## Jugar solo: sin móviles ni red; las opciones se eligen con el ratón en la pantalla del juego.
func _on_solo_pressed() -> void:
	if _starting:
		return
	_starting = true
	PhoneBridge.use_local_only()
	_go_to_intro()


## Jugar con móviles: abre el lobby y se conecta con el backend.
func _on_multiplayer_pressed() -> void:
	_mode_box.visible = false
	lobby.visible = true
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


## Desde el lobby: volver a elegir modo (se cierra la sala).
func _on_lobby_back_pressed() -> void:
	if _starting:
		return
	PhoneBridge.use_local_only()
	lobby.visible = false
	_mode_box.visible = true


func _on_local_pressed() -> void:
	_on_solo_pressed()


func _on_options_button_pressed() -> void:
	options.visible = true


func _on_credits_button_pressed() -> void:
	mainButtons.visible = false
	_credits.visible = true


func _on_credits_back_pressed() -> void:
	_credits.visible = false
	mainButtons.visible = true


func _build_credits() -> void:
	_credits = Control.new()
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits.visible = false
	add_child(_credits)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits.add_child(shade)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.offset_left = -CREDITS_WIDTH / 2.0
	content.offset_right = CREDITS_WIDTH / 2.0
	content.offset_top = -CREDITS_HEIGHT / 2.0
	content.offset_bottom = CREDITS_HEIGHT / 2.0
	content.add_theme_constant_override("separation", 12)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	_credits.add_child(content)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.custom_minimum_size.y = 58.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("normal_font", MenuStyle.FONT)
	title.add_theme_font_size_override("normal_font_size", 28)
	title.text = "[center][color=#ffffff]RED PLANET SURVIVORS[/color][/center]"
	content.add_child(title)

	var subtitle := RichTextLabel.new()
	subtitle.bbcode_enabled = true
	subtitle.fit_content = true
	subtitle.scroll_active = false
	subtitle.custom_minimum_size.y = 40.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("normal_font", MenuStyle.FONT)
	subtitle.add_theme_font_size_override("normal_font_size", 14)
	subtitle.text = "[center][color=#ffd933]A project by Sticky Bit Triggers[/color]\n[color=#d9d9e3]for the NASA Space Apps Challenge Zaragoza[/color][/center]"
	content.add_child(subtitle)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.y = 390.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_override("normal_font", MenuStyle.FONT)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.text = """[center]
[color=#66e680][font_size=17]GAME ENGINE DEVELOPMENT (GODOT)[/font_size][/color]
Hector Manzano Miranda
Javier Martínez Virto

[color=#66e680][font_size=17]BACKEND ARCHITECTURE & CONTROLLER (NODE.JS & VUE)[/font_size][/color]
Robert Sebastian Visu
Rodrigo Herce Alonso

[color=#66e680][font_size=17]USER INTERFACE DESIGN (UI/UX)[/font_size][/color]
Javier Martínez Virto
Robert Sebastian Visu

[color=#66e680][font_size=17]NARRATIVE DESIGN & EVENT IMPLEMENTATION[/font_size][/color]
Mijayl Mandzyak Melnyk
Razvan Ghita Calangiu

[color=#66e680][font_size=17]MUSIC & SOUND DESIGN[/font_size][/color]
Hector Manzano Miranda

[color=#66e680][font_size=17]QUALITY ASSURANCE & TESTING[/font_size][/color]
Hector Manzano Miranda · Mijayl Mandzyak Melnyk
Razvan Ghita Calangiu · Rodrigo Herce Alonso
[/center]"""
	content.add_child(text)

	var footer := RichTextLabel.new()
	footer.bbcode_enabled = true
	footer.fit_content = true
	footer.scroll_active = false
	footer.custom_minimum_size.y = 36.0
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("normal_font", MenuStyle.FONT)
	footer.add_theme_font_size_override("normal_font_size", 13)
	footer.text = "[center][color=#ffffff]20 Sols · 4 Astronauts · One Single Decision[/color]\n[color=#ffd933]Sticky Bit Triggers · Zaragoza, 2026[/color][/center]"
	content.add_child(footer)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220.0, 64.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	MenuStyle.apply(back, 18)
	back.pressed.connect(_on_credits_back_pressed)
	content.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if _credits != null and _credits.visible and event.is_action_pressed("ui_cancel"):
		_on_credits_back_pressed()


# ---------------------------------------------------------------- Red

func _on_net_connected() -> void:
	if lobby.visible:
		Net.create_room()


func _on_connection_failed() -> void:
	if not lobby.visible:
		return
	_show_info("[color=#ff9a7a]Could not reach the game server.[/color]\nNo problem: press \"Play solo instead\" to play on this screen with the mouse.")
	_refresh_members([])
	_update_start_button()


func _on_net_disconnected() -> void:
	if not lobby.visible or _starting:
		return
	_show_info("[color=#ff9a7a]The connection to the game server was lost.[/color]\nPress Back and try again, or press \"Play solo instead\".")
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
	_qr_box.visible = false


## QR a la derecha de las instrucciones del lobby. El texto se estrecha para dejarle sitio.
func _build_qr_box() -> void:
	info_label.offset_right = 266.0
	_qr_box = VBoxContainer.new()
	_qr_box.set_anchors_preset(Control.PRESET_CENTER)
	_qr_box.offset_left = 280.0
	_qr_box.offset_right = 280.0 + QR_SIZE
	_qr_box.offset_top = -142.0
	_qr_box.offset_bottom = -142.0 + QR_SIZE + 30.0
	_qr_box.add_theme_constant_override("separation", 6)
	_qr_box.visible = false
	$Lobby/Panel.add_child(_qr_box)

	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(QR_SIZE, QR_SIZE)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # bordes nítidos al escalar
	_qr_box.add_child(_qr_rect)

	var caption := Label.new()
	caption.text = "Scan to join"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qr_box.add_child(caption)


func _show_room_info(code: String, note: String = "") -> void:
	var lines: Array[String] = []
	lines.append("[b]Room code:[/b]  [font_size=44][b]%s[/b][/font_size]" % code)
	lines.append("")
	lines.append("[b]How to join (on a phone):[/b]")
	lines.append("1. Scan the QR code or open")
	lines.append("    [b]%s[/b]" % Net.controller_url(code))
	lines.append("2. Pick a role. When everybody is ready, press Start expedition.")
	if Net.controller_url_is_local():
		lines.append("")
		lines.append("[color=#ffd27a]Heads up: this address says \"localhost\", so phones cannot use it. Open the game with the computer's network address.[/color]")
	if not note.is_empty():
		lines.append("")
		lines.append(note)
	_show_info("\n".join(PackedStringArray(lines)))
	_qr_rect.texture = QrCode.to_texture(Net.controller_url(code), 4)
	_qr_box.visible = _qr_rect.texture != null


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
