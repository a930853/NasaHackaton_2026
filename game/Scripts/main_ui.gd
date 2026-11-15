extends Control
## Cabina de la nave (marco "hud_frame.png"). Solo muestra el estado y reenvía las
## decisiones al TurnManager; no calcula ninguna consecuencia.
##
##   Ventana grande (izquierda)  -> imagen de Marte que cambia según el evento
##   Pantalla (derecha)          -> información del evento, una estadística o el libro de palabras
##   4 botones de colores        -> Salud (rojo), Oxígeno (azul), Energía (naranja),
##                                  Fuerza de la base (morado): enseñan su estadística
##   Botón redondo               -> el evento (con móviles las opciones se ven en ellos; solo, aquí)
##   Botón ancho de abajo        -> libro de palabras científicas
##   Botón MENU (arriba derecha) -> despliega «Options» (sonido) y «Exit» (vuelve al menú principal)
##
## Con móviles (multijugador), la tripulación vota en ellos (TurnManager.cast_vote, vía PhoneBridge) y
## aquí se ve el recuento (si empata dos veces, se sortea entre las empatadas).
## Jugando solo (sin móviles) las opciones salen en esta pantalla y se eligen con el ratón.
## Texto del juego: inglés sencillo para niños de 7 a 12 años.

enum View { DECISIONS, STAT, GLOSSARY, MENU }

## Tamaño del PNG del marco y huecos (en píxeles de la imagen) donde va cada elemento.
const HUD_SIZE: Vector2 = Vector2(1680, 936)
const HUD_RECTS: Dictionary = {
	"mars": Rect2(97, 54, 746, 465),
	"screen": Rect2(957, 199, 653, 504),
	"health": Rect2(166, 605, 158, 88),
	"oxygen": Rect2(375, 605, 158, 88),
	"energy": Rect2(157, 745, 165, 93),
	"integrity": Rect2(372, 745, 162, 94),
	"decide": Rect2(656, 590, 128, 110),
	"words": Rect2(632, 785, 234, 64),
	"menu": Rect2(1000, 46, 300, 98),     # placa gris sobre la pantalla derecha, a la izquierda de las 3 ranuras
	"crew": Rect2(985, 742, 615, 182),
}
const BUTTON_INSET: float = 2.0
const BOOK_ICON_PATH: String = "res://Images/Libro.png"
const MENU_BUTTON_FONT_SIZE: int = 24
const MENU_ITEM_WIDTH: float = 360.0
const CLOSE_BUTTON_SIZE: float = 64.0     # la X, cuadrada y con el estilo azul del inicio
const CLOSE_BUTTON_MARGIN: float = 8.0

const STAT_LABELS: Dictionary = {
	"health": "Health", "oxygen": "Oxygen", "energy": "Energy", "integrity": "Base strength",
}
## Logo de cada estadística (las imágenes de res://Images/).
const STAT_ICON_TEXTURES: Dictionary = {
	"health": StatIcon.SALUD, "oxygen": StatIcon.OXIGENO,
	"energy": StatIcon.ENERGIA, "integrity": StatIcon.INTEGRIDAD,
}
## Mismo color que el borde de cada botón del marco.
const STAT_COLORS: Dictionary = {
	"health": Color(0.95, 0.27, 0.36), "oxygen": Color(0.30, 0.72, 1.0),
	"energy": Color(1.0, 0.66, 0.15), "integrity": Color(0.72, 0.42, 1.0),
}
const STAT_EXPLANATIONS: Dictionary = {
	"health": "How well the crew feels. Stress and space radiation tire everyone a little every Sol. At 0, everyone is too sick to go on. Try to keep it above 50!",
	"oxygen": "The air you breathe. It goes down every Sol until the MOXIE machine works. At 0, the base has no air!",
	"energy": "Power for the lights, the machines and the heat. Solar panels make some every Sol, but dust makes them weaker. At 0, everything shuts off!",
	"integrity": "How strong the base walls are. Wind and dust wear them down every Sol, and quakes and bumps hurt them. At 0, the base falls apart!",
}
const LOW_STAT_THRESHOLD: int = 30
const LOW_STAT_COLOR: Color = Color(1.0, 0.3, 0.3)
const HISTORY_LINES: int = 6

const ROLE_LABELS: Dictionary = {
	"engineer": "Engineer", "biologist": "Biologist", "doctor": "Doctor", "generalist": "Generalist",
}
## Colores de rol (los mismos que el albedo de los cascos): Ingeniero amarillo,
## Bióloga verde, Médico rojo y Polivalente (Generalist) blanco.
const ROLE_COLORS: Dictionary = {
	"engineer": Color(1.0, 0.85, 0.2), "biologist": Color(0.4, 0.9, 0.5),
	"doctor": Color(1.0, 0.4, 0.4), "generalist": Color(1.0, 1.0, 1.0),
}
const GENERAL_LABEL: String = "Everyone"
const WAITING_TEXT: String = "The crew is choosing on their phones..."
const SOLO_PROMPT: String = "What will the crew do? Click an option:"
const TYPING_SOUND: String = "texting"
const READING_PROMPT: String = "Read the story carefully... your options are coming!"

const DEFEAT_REASONS: Dictionary = {
	"health": "The whole crew got too sick to go on.",
	"oxygen": "The base ran out of oxygen.",
	"energy": "The base ran out of energy.",
	"integrity": "The base walls fell apart.",
}
const OBJECTIVE_NAMES: Dictionary = {
	"health": "Keep everyone's health above 50 all the time",
	"colony": "Grow 3 harvests of food",
	"rover": "Free the stuck rover",
	"sensors": "Place 3 earthquake sensors",
	"moxie": "Build the MOXIE oxygen machine",
}
const SUCCESS_BANNER: String = "[color=#7CFC9A][b]It worked![/b][/color]\n"
const FAIL_BANNER: String = "[color=#FF7B7B][b]It did not work![/b][/color]\n"
const TOAST_SECONDS: float = 2.5

## Efectos de la ventana que dependen de problemas que siguen activos.
const CONDITION_SCENES: Dictionary = {
	"dust-storm": {"effect": "dust", "intensity": 0.6},
	"solar-alert": {"effect": "flare", "intensity": 0.35},
}

@onready var mars_view: MarsView = %MarsWindow
@onready var sol_label: Label = %SolLabel
@onready var objectives_label: Label = %ObjectivesLabel
@onready var conditions_label: Label = %ConditionsLabel
@onready var debug_flare_button: Button = %DebugFlareButton
@onready var timer_label: Label = %TimerLabel
@onready var toast_label: Label = %ToastLabel
@onready var title_label: Label = %TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

@onready var right_screen: Control = %RightScreen
@onready var decisions_view: ScrollContainer = %DecisionsView
@onready var summary_label: Label = %SummaryLabel
@onready var hint_label: Label = %HintLabel
@onready var nasa_fact_label: Label = %NasaFactLabel
@onready var waiting_label: Label = %WaitingLabel
@onready var crew_panel: CrewPanel = %CrewPanel
@onready var debug_options_button: Button = %DebugOptionsButton
@onready var feedback_label: RichTextLabel = %FeedbackLabel
@onready var continue_button: Button = %ContinueButton
@onready var earth_help_button: Button = %EarthHelpButton
@onready var stat_view: Control = %StatView
@onready var stat_title: Label = %StatTitle
@onready var stat_value: Label = %StatValue
@onready var stat_bar: ProgressBar = %StatBar
@onready var stat_description: Label = %StatDescription
@onready var stat_effects: RichTextLabel = %StatEffects
@onready var stat_history: RichTextLabel = %StatHistory
@onready var glossary_view: GlossaryView = %GlossaryView

@onready var health_button: Button = %HealthButton
@onready var oxygen_button: Button = %OxygenButton
@onready var energy_button: Button = %EnergyButton
@onready var integrity_button: Button = %IntegrityButton
@onready var decide_button: Button = %DecideButton
var _event_face: EventButtonFace   # dibujo del botón EVENT (lleva la exclamación)
@onready var words_button: Button = %WordsButton

var _options_box: VBoxContainer       # opciones clicables (solo en partida individual)
var _typing_tween: Tween = null       # el texto del evento sale poco a poco
var _fact_to_show: bool = false       # dato NASA y pista de la Tierra salen al acabar de leer
var _hint_to_show: bool = false
var _stat_buttons: Dictionary = {}    # stat -> Button
var _stat_icons: Dictionary = {}      # stat -> StatIcon (dibujo en la cara del botón)
var _words_label: Label                # texto pequeño del botón del libro («3 words», «NEW!»)
var _menu_button: Button               # botón MENU de la placa de arriba a la derecha
var _menu_view: Control                # lo que despliega: «Options», «Exit» y la X para cerrar
var _options_panel: Control            # panel de sonido (res://Scenes/OptionsPanel.tscn)
var _view_before_menu: int = View.DECISIONS
var _leaving: bool = false
var _view: int = View.DECISIONS
var _selected_stat: String = "health"
var _new_words: int = 0
var _earth_panel: UiOverlay
var _end_panel: UiOverlay
var _debug_panel: UiOverlay
var _toast_tween: Tween = null

# --- Para enseñar las consecuencias en pantalla ---
var _last_stats: Dictionary = {}          # barras la última vez que se dibujaron
var _stats_at_event: Dictionary = {}      # barras al aparecer el evento actual
var _progress_at_event: Dictionary = {}   # progreso al aparecer el evento actual
var _stat_history: Dictionary = {}        # stat -> [{sol, delta, cause}]
var _suppress_deltas: bool = false        # true al reiniciar: no mostrar números flotantes


func _ready() -> void:
	_menu_button = Button.new()   # se coloca con el resto del marco en _place_hud()
	add_child(_menu_button)
	_place_hud()
	_build_buttons()
	_build_overlays()
	_build_options_box()
	_build_menu()
	toast_label.modulate.a = 0.0
	for stat in GameState.STAT_NAMES:
		_stat_history[stat] = []

	GameState.stats_changed.connect(_refresh_stats)
	GameState.progress_changed.connect(_refresh_objectives)
	GameState.conditions_changed.connect(_refresh_conditions)
	GlossaryManager.term_unlocked.connect(_on_term_unlocked)
	TurnManager.sol_started.connect(_on_sol_started)
	TurnManager.event_presented.connect(_on_event_presented)
	TurnManager.decision_resolved.connect(_on_decision_resolved)
	TurnManager.timer_updated.connect(_on_timer_updated)
	TurnManager.earth_help_changed.connect(_refresh_earth_help_button)
	TurnManager.game_ended.connect(_on_game_ended)
	TurnManager.votes_changed.connect(_on_votes_changed)
	TurnManager.reading_finished.connect(_on_reading_finished)

	continue_button.pressed.connect(TurnManager.continue_after_resolution)
	earth_help_button.pressed.connect(_open_earth_panel)
	debug_flare_button.pressed.connect(TurnManager.simulate_solar_flare)
	debug_options_button.pressed.connect(_open_debug_options)

	_show_view(View.DECISIONS)
	TurnManager.start_game()


func _process(_delta: float) -> void:
	# Los botones parpadean para llamar la atención: decisión pendiente / palabra nueva.
	var wave: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	# El botón EVENT es rojo y sencillo; solo un evento importante pendiente le pone una exclamación encima.
	_event_face.alert = TurnManager.phase == TurnManager.Phase.DECISION \
		and bool(TurnManager.current_event.get("important", false))
	var has_new_word: bool = _new_words > 0 and _view != View.GLOSSARY
	words_button.self_modulate = Color.WHITE.lerp(Color(1.0, 0.85, 0.35), wave) if has_new_word else Color.WHITE


# --------------------------------------------------------------- Construcción

## Coloca cada elemento sobre su hueco del marco usando proporciones (vale para cualquier resolución).
func _place_hud() -> void:
	_place(mars_view, HUD_RECTS["mars"])
	_place(right_screen, HUD_RECTS["screen"])
	_place(health_button, (HUD_RECTS["health"] as Rect2).grow(-BUTTON_INSET))
	_place(oxygen_button, (HUD_RECTS["oxygen"] as Rect2).grow(-BUTTON_INSET))
	_place(energy_button, (HUD_RECTS["energy"] as Rect2).grow(-BUTTON_INSET))
	_place(integrity_button, (HUD_RECTS["integrity"] as Rect2).grow(-BUTTON_INSET))
	_place(decide_button, HUD_RECTS["decide"])
	_place(words_button, (HUD_RECTS["words"] as Rect2).grow(-BUTTON_INSET))
	_place(_menu_button, HUD_RECTS["menu"])
	_place(crew_panel, HUD_RECTS["crew"])


func _place(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x / HUD_SIZE.x
	control.anchor_top = rect.position.y / HUD_SIZE.y
	control.anchor_right = rect.end.x / HUD_SIZE.x
	control.anchor_bottom = rect.end.y / HUD_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _build_buttons() -> void:
	_stat_buttons = {
		"health": health_button, "oxygen": oxygen_button,
		"energy": energy_button, "integrity": integrity_button,
	}
	var group := ButtonGroup.new()  # solo un botón "encendido" a la vez

	for stat in GameState.STAT_NAMES:
		var button: Button = _stat_buttons[stat]
		_style_hud_button(button, STAT_COLORS[stat], 10, true)
		button.button_group = group
		button.pressed.connect(_show_stat.bind(stat))
		var icon := StatIcon.new(STAT_ICON_TEXTURES[stat], STAT_COLORS[stat])
		button.add_child(icon)
		_stat_icons[stat] = icon

	_style_hud_button(decide_button, Color(0.5, 0.85, 1.0), 64)
	# El botón redondo se dibuja entero con EventButtonFace: sin estilos propios que tapen el dibujo.
	for style_name in ["normal", "hover", "pressed", "hover_pressed"]:
		decide_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	decide_button.button_group = group
	decide_button.pressed.connect(_show_view.bind(View.DECISIONS))
	_event_face = EventButtonFace.new()
	_event_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	decide_button.add_child(_event_face)

	_style_hud_button(words_button, Color(0.35, 0.7, 1.0), 8)
	words_button.button_group = group
	words_button.pressed.connect(_show_glossary)
	_build_words_face()


## Estilo común: fondo oscuro de pantalla, borde de color al pasar el ratón y al estar elegido.
## `light` = true: cara clara (para los logos de borde negro de las estadísticas).
func _style_hud_button(button: Button, accent: Color, radius: int, light: bool = false) -> void:
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	var normal_fill: Color = Color(0.8, 0.86, 0.94) if light else Color(0.05, 0.08, 0.14)
	var hover_fill: Color = Color(0.9, 0.95, 1.0) if light else Color(0.1, 0.15, 0.26)
	var pressed_fill: Color = accent.lerp(Color.WHITE, 0.62) if light else Color(0.13, 0.2, 0.34)
	var pressed_box: StyleBoxFlat = _make_box(pressed_fill, accent, radius, 3)
	button.add_theme_stylebox_override("normal", _make_box(normal_fill, Color(0, 0, 0, 0), radius, 0))
	button.add_theme_stylebox_override("hover", _make_box(hover_fill, accent, radius, 2))
	button.add_theme_stylebox_override("pressed", pressed_box)
	button.add_theme_stylebox_override("hover_pressed", pressed_box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _make_box(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


## Cara del botón del libro: un libro en pixel art a la izquierda y, a su lado, el nombre y cuántas
## palabras se han descubierto. Si hay una nueva, el contador se pone ámbar con «NEW!».
func _build_words_face() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	words_button.add_child(row)

	if ResourceLoader.exists(BOOK_ICON_PATH):   # si aún no se importó, el botón sale solo con texto
		var icon := TextureRect.new()
		icon.texture = load(BOOK_ICON_PATH)
		icon.custom_minimum_size = Vector2(44.0, 44.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", -3)
	row.add_child(texts)

	var title := Label.new()
	title.text = "WORD BOOK"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.12))
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)

	_words_label = Label.new()
	_words_label.add_theme_font_size_override("font_size", 13)
	_words_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_words_label)


## Botón MENU de la placa de arriba a la derecha y lo que despliega: una capa que tapa TODA la pantalla
## derecha con «Options» (sonido), «Exit» (vuelve al menú principal) y una X arriba a la derecha para volver atrás.
## Todos con el estilo azul del menú de inicio (MenuStyle).
func _build_menu() -> void:
	_menu_button.text = "MENU"
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.tooltip_text = "Options and exit"
	MenuStyle.apply(_menu_button, MENU_BUTTON_FONT_SIZE)
	_menu_button.pressed.connect(_on_menu_button_pressed)

	_menu_view = Control.new()
	_menu_view.visible = false
	right_screen.add_child(_menu_view)   # el PanelContainer lo estira por toda la pantalla; el contenido normal se oculta

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_view.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(MENU_ITEM_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var options_button := Button.new()
	options_button.text = "Options"
	options_button.tooltip_text = "Change the sound"
	MenuStyle.apply(options_button, MENU_BUTTON_FONT_SIZE)
	options_button.pressed.connect(_on_menu_options_pressed)
	column.add_child(options_button)

	var exit_button := Button.new()
	exit_button.text = "Exit"
	exit_button.tooltip_text = "Leave the mission and go back to the main menu"
	MenuStyle.apply(exit_button, MENU_BUTTON_FONT_SIZE)
	exit_button.pressed.connect(_on_menu_exit_pressed)
	column.add_child(exit_button)

	# X arriba a la derecha para volver atrás
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close the menu"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -CLOSE_BUTTON_SIZE - CLOSE_BUTTON_MARGIN
	close_button.offset_right = -CLOSE_BUTTON_MARGIN
	close_button.offset_top = CLOSE_BUTTON_MARGIN
	close_button.offset_bottom = CLOSE_BUTTON_SIZE + CLOSE_BUTTON_MARGIN
	close_button.custom_minimum_size = Vector2(CLOSE_BUTTON_SIZE, CLOSE_BUTTON_SIZE)
	MenuStyle.apply(close_button, MENU_BUTTON_FONT_SIZE)   # mismo estilo azul que los botones del inicio
	close_button.pressed.connect(_close_menu)
	_menu_view.add_child(close_button)

	_options_panel = (load("res://Scenes/OptionsPanel.tscn") as PackedScene).instantiate()
	add_child(_options_panel)   # el último hijo se dibuja encima de todo; empieza oculto


func _on_menu_button_pressed() -> void:
	if _view == View.MENU:
		_close_menu()
		return
	_view_before_menu = _view
	_show_view(View.MENU)


## La X: vuelve a lo que se estaba viendo (evento, una barra o el libro).
func _close_menu() -> void:
	match _view_before_menu:
		View.STAT:
			_show_stat(_selected_stat)
		View.GLOSSARY:
			_show_glossary()
		_:
			_show_view(View.DECISIONS)


func _on_menu_options_pressed() -> void:
	Events.sfx_requested.emit("click", 0.05)
	_options_panel.visible = true


## Salir de la partida: de vuelta al menú principal (cierra también la sala si era multijugador).
func _on_menu_exit_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Events.sfx_requested.emit("click", 0.05)
	Events.scene_change_requested.emit("menu")


## Contenedor de las opciones para jugar solo: va en la pantalla derecha, justo bajo el aviso de espera.
func _build_options_box() -> void:
	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.visible = false
	var parent: Node = waiting_label.get_parent()
	parent.add_child(_options_box)
	parent.move_child(_options_box, waiting_label.get_index() + 1)


## Partida individual: sin móviles, las opciones se eligen con el ratón en esta pantalla.
func _is_solo() -> bool:
	return not PhoneBridge.active


## Vuelve a dibujar las opciones clicables. Solo hay mientras se espera una decisión en partida individual.
func _refresh_options_box() -> void:
	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	var show_options: bool = _is_solo() and TurnManager.phase == TurnManager.Phase.DECISION \
		and not TurnManager.reading
	_options_box.visible = show_options
	if not show_options:
		return
	for option in TurnManager.current_event.get("options", []):
		_options_box.add_child(_make_option_card(option))


func _build_overlays() -> void:
	_earth_panel = UiOverlay.new(Vector2(640, 420))
	add_child(_earth_panel)

	_end_panel = UiOverlay.new(Vector2(760, 520))
	add_child(_end_panel)

	_debug_panel = UiOverlay.new(Vector2(640, 470))
	add_child(_debug_panel)


# ----------------------------------------------------- Qué enseña la pantalla derecha

func _show_view(view: int) -> void:
	_view = view
	decisions_view.visible = view == View.DECISIONS
	stat_view.visible = view == View.STAT
	glossary_view.visible = view == View.GLOSSARY
	_menu_view.visible = view == View.MENU
	right_screen.get_node("ScreenMargin").visible = view != View.MENU   # el menú tapa toda la pantalla derecha
	if view == View.DECISIONS:
		decide_button.button_pressed = true


func _show_stat(stat: String) -> void:
	_selected_stat = stat
	_show_view(View.STAT)
	_stat_buttons[stat].button_pressed = true
	_refresh_stat_view()


func _show_glossary() -> void:
	_new_words = 0
	_refresh_words_button()
	glossary_view.refresh()
	_show_view(View.GLOSSARY)
	words_button.button_pressed = true


# ------------------------------------------------------------------- Refrescos

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_objectives()
	_refresh_conditions()
	_refresh_earth_help_button()
	crew_panel.refresh()
	debug_options_button.disabled = TurnManager.phase != TurnManager.Phase.DECISION or TurnManager.reading
	debug_options_button.visible = not _is_solo()   # solo: las opciones ya están en pantalla


func _refresh_stats() -> void:
	for stat in GameState.STAT_NAMES:
		var value: int = GameState.get_stat(stat)
		# El dibujo se llena según el valor; al pasar el ratón se lee el número.
		var animate: bool = _last_stats.has(stat) and not _suppress_deltas
		(_stat_icons[stat] as StatIcon).set_level(float(value) / float(GameState.STAT_MAX), animate)
		(_stat_buttons[stat] as Button).tooltip_text = "%s: %d / %d" % [STAT_LABELS[stat], value, GameState.STAT_MAX]

		# Cada cambio de una estadística sube flotando desde su botón (+15 verde, -10 rojo).
		if _last_stats.has(stat) and not _suppress_deltas:
			var delta: int = value - int(_last_stats[stat])
			if delta != 0:
				_spawn_delta(_stat_buttons[stat], delta)
				_record_history(stat, delta)
		_last_stats[stat] = value
	if _view == View.STAT:
		_refresh_stat_view()


func _refresh_stat_view() -> void:
	var stat: String = _selected_stat
	var value: int = GameState.get_stat(stat)
	var color: Color = LOW_STAT_COLOR if value <= LOW_STAT_THRESHOLD else STAT_COLORS[stat]
	stat_title.text = STAT_LABELS[stat].to_upper()
	stat_title.add_theme_color_override("font_color", STAT_COLORS[stat])
	stat_value.text = "%d / %d" % [value, GameState.STAT_MAX]
	stat_bar.value = value
	stat_bar.modulate = color
	stat_description.text = STAT_EXPLANATIONS[stat]
	stat_effects.text = "[b]Right now[/b]\n" + _stat_effects_text(stat)
	stat_history.text = "[b]What changed it[/b]\n" + _stat_history_text(stat)


## Qué está afectando ahora mismo a esta estadística.
func _stat_effects_text(stat: String) -> String:
	var lines: Array[String] = []
	if stat == "oxygen":
		if GameState.moxie_progress >= 100:
			lines.append("MOXIE is working: no air is lost each Sol.")
		else:
			lines.append("Everyone breathes: -%d each Sol until MOXIE works." % GameState.PASSIVE_OXYGEN_LOSS)
	elif stat == "energy":
		lines.append("Solar panels: +%d each Sol%s." % [GameState.passive_energy_gain(),
			" (dusty)" if GameState.current_sol >= GameState.DUSTY_PANELS_FROM_SOL else ""])
	elif stat == "integrity":
		lines.append("Wind and dust: -%d each Sol." % GameState.PASSIVE_INTEGRITY_LOSS)
	elif stat == "health":
		if GameState.current_sol >= GameState.HEALTH_LOSS_FROM_SOL:
			lines.append("Stress and radiation: -%d each Sol." % GameState.PASSIVE_HEALTH_LOSS)
		else:
			lines.append("Everyone is fresh for now. From Sol %d, stress and radiation cost -%d each Sol." % [
				GameState.HEALTH_LOSS_FROM_SOL, GameState.PASSIVE_HEALTH_LOSS])
	for condition in GameState.active_conditions:
		var effects: Dictionary = _next_condition_effects(condition)
		if effects.has(stat):
			var sols_left: int = int(condition["sols_left"])
			lines.append("%s: %+d each morning (%d Sol%s left)" % [
				condition.get("name", condition["id"]), int(effects[stat]), sols_left, "" if sols_left == 1 else "s"])
	return "\n".join(PackedStringArray(lines)) if not lines.is_empty() else "Nothing special."


func _next_condition_effects(condition: Dictionary) -> Dictionary:
	if condition.has("sequence"):
		var sequence: Array = condition["sequence"]
		var step: int = int(condition["step"])
		return sequence[step] if step < sequence.size() else {}
	return condition.get("daily", {})


func _stat_history_text(stat: String) -> String:
	var entries: Array = _stat_history[stat]
	if entries.is_empty():
		return "No changes yet."
	var lines: Array[String] = []
	for i in range(entries.size() - 1, maxi(entries.size() - 1 - HISTORY_LINES, -1), -1):
		var entry: Dictionary = entries[i]
		var color: String = "7CFC9A" if int(entry["delta"]) > 0 else "FF7B7B"
		lines.append("[color=#%s]%+d[/color]  Sol %d: %s" % [color, int(entry["delta"]), int(entry["sol"]), entry["cause"]])
	return "\n".join(PackedStringArray(lines))


func _record_history(stat: String, delta: int) -> void:
	_stat_history[stat].append({"sol": GameState.current_sol, "delta": delta, "cause": _current_cause()})


## Qué provocó un cambio: la mañana de un Sol o la decisión del evento actual.
func _current_cause() -> String:
	if TurnManager.phase == TurnManager.Phase.SOL_START:
		return "Morning news"
	return str(TurnManager.current_event.get("title", "Event"))


## Número flotante que sube desde un botón y se desvanece.
func _spawn_delta(anchor: Control, delta: int) -> void:
	var popup := Label.new()
	popup.text = "%+d" % delta
	popup.add_theme_font_size_override("font_size", 30)
	popup.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if delta > 0 else Color(1.0, 0.4, 0.4))
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 6)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	var start: Vector2 = anchor.global_position - global_position + Vector2(anchor.size.x * 0.5 - 14.0, -8.0)
	popup.position = start
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", start.y - 70.0, 1.4)
	tween.tween_property(popup, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)


func _refresh_objectives() -> void:
	var alert_text: String = " (early warning ON!)" if GameState.seismic_alert_active else ""
	objectives_label.text = "Harvests %d/%d  |  Rover: %s  |  Sensors %d/%d%s  |  MOXIE %d%%" % [
		GameState.harvests_completed, GameState.HARVEST_GOAL,
		"free" if GameState.rover_rescued else "stuck",
		GameState.sensors_placed, GameState.SENSOR_GOAL, alert_text,
		GameState.moxie_progress]
	_refresh_words_button()


func _refresh_words_button() -> void:
	if _words_label == null:
		return
	var count: int = GameState.unlocked_terms.size()
	var text: String = "%d word%s" % [count, "" if count == 1 else "s"]
	if _new_words > 0:
		text = "NEW!  " + text
	_words_label.text = text
	_words_label.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.35) if _new_words > 0 else Color(0.6, 0.8, 1.0))


func _refresh_conditions() -> void:
	var parts: Array[String] = []
	for condition in GameState.active_conditions:
		var sols_left: int = int(condition["sols_left"])
		parts.append("%s: %d Sol%s left" % [
			condition.get("name", condition["id"]), sols_left, "" if sols_left == 1 else "s"])
	for waiting in TurnManager.waiting_events():
		parts.append("Waiting for Earth: %s (Sol %d)" % [waiting["title"], waiting["return_sol"]])
	conditions_label.visible = not parts.is_empty()
	conditions_label.text = "Problems: " + " • ".join(PackedStringArray(parts))
	if _view == View.STAT:
		_refresh_stat_view()


func _refresh_earth_help_button() -> void:
	var available: bool = TurnManager.can_request_earth_help()
	earth_help_button.disabled = not available
	if available:
		earth_help_button.tooltip_text = "Ask Earth for a hint. The radio needs %d Sols to recharge after each message." % GameState.EARTH_HELP_COOLDOWN_SOLS
	elif GameState.earth_help_blocked():
		earth_help_button.tooltip_text = "The solar storm is blocking radio messages."
	elif GameState.earth_help_cooldown_left() > 0:
		var left: int = GameState.earth_help_cooldown_left()
		earth_help_button.tooltip_text = "The radio is recharging. Ready in %d Sol%s." % [left, "" if left == 1 else "s"]
	else:
		earth_help_button.tooltip_text = "Not now. Earth cannot help with emergencies."


# -------------------------------------------------------- Señales del TurnManager

func _on_sol_started(sol: int, _lines: Array) -> void:
	sol_label.text = "Sol %d / %d" % [sol, GameState.MAX_SOLS]
	if sol == 1:
		# Partida nueva: sincroniza las barras sin números flotantes y borra el historial.
		for stat in GameState.STAT_NAMES:
			_last_stats[stat] = GameState.get_stat(stat)
			_stat_history[stat] = []
		_new_words = 0
		_suppress_deltas = false
	# Las noticias del amanecer («el ingeniero ha vuelto», «el oxígeno bajó»...) ya no se escriben sobre el
	# evento: las barras enseñan sus cambios y los avatares, quién está en la base.
	summary_label.text = ""
	summary_label.visible = false
	feedback_label.visible = false
	continue_button.visible = false
	_refresh_all()


func _on_event_presented(event: Dictionary, hint: String) -> void:
	feedback_label.visible = false
	continue_button.visible = false
	timer_label.visible = false

	# Pantalla derecha: la información del evento. Las opciones, en los móviles (o aquí, jugando solo).
	title_label.text = str(event.get("title", ""))
	description_label.text = str(event.get("description", ""))
	var fact: String = str(event.get("nasa_fact", ""))
	nasa_fact_label.text = "NASA fact: " + fact
	hint_label.text = hint
	# El texto sale poco a poco para que se lea; el dato NASA, la pista y las opciones salen al acabar.
	_fact_to_show = not fact.is_empty()
	_hint_to_show = not hint.is_empty()
	nasa_fact_label.visible = _fact_to_show and not TurnManager.reading
	hint_label.visible = _hint_to_show and not TurnManager.reading
	_start_typing(TurnManager.reading)

	# Foto de cómo estaba todo antes de decidir, para enseñar después qué cambió.
	for stat in GameState.STAT_NAMES:
		_stats_at_event[stat] = GameState.get_stat(stat)
	_progress_at_event = _progress_snapshot()

	waiting_label.text = _waiting_text()
	waiting_label.visible = true
	_debug_panel.close()
	_refresh_options_box()
	decisions_view.scroll_vertical = 0

	mars_view.show_scene(_scene_for(event))
	_show_view(View.DECISIONS)
	_refresh_all()


## Escribe la descripción letra a letra (o la enseña entera si ya se había leído, p. ej. en un desempate).
func _start_typing(animate: bool) -> void:
	if _typing_tween != null:
		_typing_tween.kill()
		_typing_tween = null
	if not animate:
		description_label.visible_ratio = 1.0
		_stop_typing_sound()
		return
	description_label.visible_ratio = 0.0
	_typing_tween = create_tween()
	_typing_tween.tween_property(description_label, "visible_ratio", 1.0, TurnManager.reading_seconds)
	_typing_tween.finished.connect(_stop_typing_sound)
	Events.sfx_requested.emit(TYPING_SOUND, 0.0)   # suena mientras se escribe el texto


func _stop_typing() -> void:
	if _typing_tween != null:
		_typing_tween.kill()
		_typing_tween = null
	description_label.visible_ratio = 1.0
	_stop_typing_sound()


func _stop_typing_sound() -> void:
	Events.sfx_stop_requested.emit(TYPING_SOUND)


func _exit_tree() -> void:
	_stop_typing_sound()   # por si se sale de la partida mientras sale el texto


## Se acabó el tiempo de lectura: sale lo que faltaba (dato NASA, pista) y ya se puede elegir.
func _on_reading_finished() -> void:
	_stop_typing()
	nasa_fact_label.visible = _fact_to_show
	hint_label.visible = _hint_to_show
	waiting_label.text = _waiting_text()
	_refresh_options_box()
	_refresh_all()


func _waiting_text() -> String:
	if TurnManager.reading:
		return READING_PROMPT
	if _is_solo():
		return SOLO_PROMPT
	return "%s %s" % [WAITING_TEXT, TurnManager.vote_progress_text()]


## Recuento de la votación de los móviles.
func _on_votes_changed() -> void:
	if TurnManager.phase == TurnManager.Phase.DECISION:
		waiting_label.text = _waiting_text()


## Escena de Marte del evento. Si no trae efecto propio, hereda el de un problema activo
## (una tormenta de polvo sigue viéndose aunque el evento sea otro).
func _scene_for(event: Dictionary) -> Dictionary:
	var scene: Dictionary = (event.get("scene", {}) as Dictionary).duplicate()
	if str(scene.get("effect", "none")) == "none":
		scene.merge(_condition_scene(), true)
	return scene


func _condition_scene() -> Dictionary:
	for condition_id in CONDITION_SCENES:
		if GameState.is_condition_active(condition_id):
			return CONDITION_SCENES[condition_id]
	return {"effect": "none"}


## Tarjeta de una opción: crece hasta que quepa todo el texto. Solo el rol va en color.
## Si la opción está bloqueada (alguien está fuera de la base), se ve apagada y explica por qué.
func _make_option_card(option: Dictionary) -> OptionCard:
	var role: Variant = option.get("role")
	var role_tag: String
	if role == null:
		role_tag = "[b]%s:[/b]" % GENERAL_LABEL
	else:
		var hex: String = (ROLE_COLORS.get(role, Color.WHITE) as Color).to_html(false)
		role_tag = "[color=#%s][b]%s:[/b][/color]" % [hex, ROLE_LABELS.get(role, role)]
	var text: String = "%s %s\n%s" % [role_tag, option["label"], OptionInfo.costs_text(option)]
	var reason: String = TurnManager.option_block_reason(option)
	if not reason.is_empty():
		text += "\n[color=#FF7B7B]%s[/color]" % reason
	var card := OptionCard.new(text)
	card.disabled = not reason.is_empty()
	card.chosen.connect(_on_option_pressed.bind(str(option["id"])))
	return card


## Simulador de móvil (solo para depurar): enseña TODAS las opciones del evento tal y como
## las verían los móviles de cada rol, y deja elegir una. Con móviles reales se podrá quitar:
## TurnManager.controller_view_for(role) ya prepara los datos que recibirá cada mando.
func _open_debug_options() -> void:
	if TurnManager.phase != TurnManager.Phase.DECISION:
		return
	_debug_panel.clear_content()
	_debug_panel.content.add_child(_debug_panel.make_title("Phone simulator (debug)"))
	_debug_panel.content.add_child(_debug_panel.make_text("The crew would see these options on their phones."))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_debug_panel.content.add_child(scroll)
	for option in TurnManager.current_event.get("options", []):
		list.add_child(_make_option_card(option))

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_debug_panel.close)
	_debug_panel.content.add_child(close)
	_debug_panel.open()


## Opción elegida con el ratón (jugando solo) o desde el simulador de móvil de depuración.
func _on_option_pressed(option_id: String) -> void:
	_debug_panel.close()
	TurnManager.submit_choice(option_id)


func _on_decision_resolved(option: Dictionary, feedback: String, success: bool) -> void:
	_stop_typing()
	nasa_fact_label.visible = _fact_to_show
	hint_label.visible = _hint_to_show
	waiting_label.visible = false
	_refresh_options_box()   # ya no hay nada que elegir: se quitan las opciones
	_debug_panel.close()
	timer_label.visible = false
	var banner: String = ""
	var chosen_text: String = ""
	if not option.is_empty():
		banner = SUCCESS_BANNER if success else FAIL_BANNER
		chosen_text = "[b]You chose:[/b] %s\n\n" % option["label"]
	feedback_label.text = chosen_text + banner + feedback + _change_summary()
	feedback_label.visible = true
	continue_button.visible = true
	continue_button.grab_focus()
	decisions_view.scroll_vertical = 0

	# La ventana también cambia: si lo resuelves, el efecto se calma; si falla, el problema sigue.
	if not option.is_empty() and success:
		var calmed: Dictionary = (TurnManager.current_event.get("scene", {}) as Dictionary).duplicate()
		calmed.merge(_condition_scene(), true)
		mars_view.show_scene(calmed)

	_show_view(View.DECISIONS)
	_refresh_all()


## Contadores de progreso que se comparan antes y después de decidir.
func _progress_snapshot() -> Dictionary:
	return {
		"Harvests": GameState.harvests_completed,
		"Sensors placed": GameState.sensors_placed,
		"MOXIE": GameState.moxie_progress,
		"Rover freed": 1 if GameState.rover_rescued else 0,
	}


## Texto (con colores) de todo lo que cambió por la decisión: barras y progreso.
func _change_summary() -> String:
	var parts: Array[String] = []
	for stat in GameState.STAT_NAMES:
		var diff: int = GameState.get_stat(stat) - int(_stats_at_event.get(stat, GameState.get_stat(stat)))
		if diff != 0:
			var color: String = "7CFC9A" if diff > 0 else "FF7B7B"
			parts.append("[color=#%s]%s %+d[/color]" % [color, STAT_LABELS[stat], diff])

	var progress_now: Dictionary = _progress_snapshot()
	var progress_parts: Array[String] = []
	for key in progress_now:
		var before: int = int(_progress_at_event.get(key, progress_now[key]))
		var after: int = int(progress_now[key])
		if after == before:
			continue
		if key == "Rover freed":
			progress_parts.append("[color=#7CFC9A]The rover is free![/color]")
		elif key == "MOXIE":
			progress_parts.append("MOXIE %d%% > %d%%" % [before, after])
		else:
			progress_parts.append("%s %d > %d" % [key, before, after])

	var text: String = ""
	if not parts.is_empty():
		text += "\n\n[b]What changed:[/b] " + ", ".join(PackedStringArray(parts))
	if not progress_parts.is_empty():
		text += "\n[b]Progress:[/b] " + ", ".join(PackedStringArray(progress_parts))
	return text


func _on_timer_updated(seconds_left: int) -> void:
	timer_label.visible = seconds_left >= 0
	timer_label.text = "Hurry up! %d s" % maxi(seconds_left, 0)


# ------------------------------------------------------------ Libro / avisos

func _on_term_unlocked(_term_id: String, title: String) -> void:
	if _view != View.GLOSSARY:
		_new_words += 1
	toast_label.text = "New word added to the Word Book: %s" % title
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	_refresh_words_button()


# ------------------------------------------------------------ Ayuda de la Tierra

func _open_earth_panel() -> void:
	GlossaryManager.unlock("minutos_luz")
	_earth_panel.clear_content()
	_earth_panel.content.add_child(_earth_panel.make_title("Ask Earth for help"))
	_earth_panel.content.add_child(_earth_panel.make_text(TurnManager.EARTH_DISTANCE_TEXT))
	_earth_panel.content.add_child(_earth_panel.make_text(
		"Today's problem will wait and you will move on to the next Sol. When Earth answers, the problem comes back with a hint."))
	for choice in TurnManager.EARTH_HELP_OPTIONS:
		var button := Button.new()
		button.text = str(choice["label"])
		button.custom_minimum_size = Vector2(0, 60)
		button.pressed.connect(_on_earth_choice.bind(str(choice["id"])))
		_earth_panel.content.add_child(button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_earth_panel.close)
	_earth_panel.content.add_child(cancel)
	_earth_panel.open()


func _on_earth_choice(choice_id: String) -> void:
	_earth_panel.close()
	TurnManager.request_earth_help(choice_id)


# ---------------------------------------------------------------------- Final

func _on_game_ended(victory: bool, report: Dictionary) -> void:
	_end_panel.clear_content()
	var content: VBoxContainer = _end_panel.content
	content.add_child(_end_panel.make_title("Mission complete!" if victory else "Mission failed"))

	if victory:
		content.add_child(_end_panel.make_text("You survived %d Sols on Mars! Great teamwork!" % GameState.MAX_SOLS))
	else:
		var stat: String = str(report["reason"]).trim_prefix("defeat:")
		content.add_child(_end_panel.make_text(
			"%s (Sol %d)\nReal space teams also fail sometimes. They learn and try again!" % [
				DEFEAT_REASONS.get(stat, "The mission is over."), report["sol"]]))

	var objective_lines: Array[String] = []
	var status: Dictionary = report["objectives"]
	for key in OBJECTIVE_NAMES:
		objective_lines.append("%s  %s" % ["[DONE]" if status[key] else "[ -- ]", OBJECTIVE_NAMES[key]])
	content.add_child(_end_panel.make_text("\n".join(PackedStringArray(objective_lines))))
	content.add_child(_end_panel.make_text("Score: %d" % report["score"]))
	content.add_child(_end_panel.make_text("Words discovered: %d of %d" % [
		report["terms_unlocked"], report["terms_total"]]))

	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(0, 44)
	again.pressed.connect(_on_play_again)
	content.add_child(again)

	var menu := Button.new()
	menu.text = "Back to menu"
	menu.custom_minimum_size = Vector2(0, 44)
	menu.pressed.connect(func() -> void: Events.scene_change_requested.emit("menu"))
	content.add_child(menu)

	_end_panel.open()


func _on_play_again() -> void:
	_end_panel.close()
	_suppress_deltas = true  # el reinicio no debe mostrar números flotantes
	TurnManager.start_game()
