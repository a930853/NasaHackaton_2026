extends Control
## Cabina de la nave (marco "hud_frame.png"). Solo muestra el estado y reenvía las
## decisiones al TurnManager; no calcula ninguna consecuencia.
##
##   Ventana grande (izquierda)  -> imagen de Marte que cambia según el evento
##   Pantalla (derecha)          -> información del evento, una estadística o el libro de palabras
##   4 botones de colores        -> Salud (rojo), Oxígeno (azul), Energía (naranja),
##                                  Fuerza de la base (morado): enseñan su estadística
##   Botón redondo               -> el evento (las opciones se ven en los móviles)
##   Botón ancho de abajo        -> libro de palabras científicas
##
## Con móviles, la tripulación vota en ellos (TurnManager.cast_vote, vía PhoneBridge) y aquí se ve
## el recuento (si empata dos veces, se sortea entre las empatadas).
## Texto del juego: inglés sencillo para niños de 7 a 12 años.

enum View { DECISIONS, STAT, GLOSSARY }

## Tamaño del PNG del marco y huecos (en píxeles de la imagen) donde va cada elemento.
const HUD_SIZE: Vector2 = Vector2(1680, 936)
const HUD_RECTS: Dictionary = {
	"mars": Rect2(97, 54, 746, 465),
	"screen": Rect2(957, 199, 653, 504),
	"health": Rect2(166, 605, 158, 88),
	"oxygen": Rect2(375, 605, 158, 88),
	"energy": Rect2(157, 745, 165, 93),
	"integrity": Rect2(372, 745, 162, 94),
	"decide": Rect2(657, 608, 128, 110),
	"words": Rect2(632, 785, 234, 64),
	"crew": Rect2(985, 742, 615, 182),
}
const BUTTON_INSET: float = 2.0

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
	"health": "How well the crew feels. If it drops to 0, everyone is too sick to go on. Try to keep it above 50!",
	"oxygen": "The air you breathe. It goes down every Sol until the MOXIE machine works. At 0, the base has no air!",
	"energy": "Power for the lights, the machines and the heat. Solar panels make some every Sol. At 0, everything shuts off!",
	"integrity": "How strong the base walls are. Quakes, storms and bumps hurt it. At 0, the base falls apart!",
}
const LOW_STAT_THRESHOLD: int = 30
const LOW_STAT_COLOR: Color = Color(1.0, 0.3, 0.3)
const HISTORY_LINES: int = 6

const ROLE_LABELS: Dictionary = {
	"engineer": "Engineer", "biologist": "Biologist", "doctor": "Doctor", "generalist": "Commander",
}
## Colores de rol (los mismos que el albedo de los cascos): Ingeniero amarillo,
## Bióloga verde, Médico rojo y Polivalente (Commander) blanco.
const ROLE_COLORS: Dictionary = {
	"engineer": Color(1.0, 0.85, 0.2), "biologist": Color(0.4, 0.9, 0.5),
	"doctor": Color(1.0, 0.4, 0.4), "generalist": Color(1.0, 1.0, 1.0),
}
const GENERAL_LABEL: String = "Everyone"
const WAITING_TEXT: String = "The crew is choosing on their phones..."

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

var _stat_buttons: Dictionary = {}    # stat -> Button
var _stat_icons: Dictionary = {}      # stat -> StatIcon (dibujo en la cara del botón)
var _words_label: Label
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
	_place_hud()
	_build_buttons()
	_build_overlays()
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
	_place(decide_button, (HUD_RECTS["decide"] as Rect2).grow(-BUTTON_INSET))
	_place(words_button, (HUD_RECTS["words"] as Rect2).grow(-BUTTON_INSET))
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
	decide_button.add_child(_event_face)

	_style_hud_button(words_button, Color(0.35, 0.7, 1.0), 8)
	words_button.button_group = group
	words_button.pressed.connect(_show_glossary)
	var words_face: Dictionary = _build_face(words_button, "WORD BOOK", 13, 0)
	_words_label = words_face["name"]


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


## Texto sobre el botón: nombre pequeño y, opcionalmente, un número grande debajo.
func _build_face(button: Button, title: String, title_size: int, value_size: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -2)
	button.add_child(box)

	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", title_size)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var value_label: Label = null
	if value_size > 0:
		value_label = Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", value_size)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(value_label)
	return {"name": name_label, "value": value_label}


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
	debug_options_button.disabled = TurnManager.phase != TurnManager.Phase.DECISION


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
	elif stat == "energy" and GameState.PASSIVE_ENERGY_GAIN > 0:
		lines.append("Solar panels: +%d each Sol." % GameState.PASSIVE_ENERGY_GAIN)
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
	var text: String = "WORD BOOK (%d)" % GameState.unlocked_terms.size()
	if _new_words > 0:
		text += "  NEW!"
	_words_label.text = text


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

func _on_sol_started(sol: int, lines: Array) -> void:
	sol_label.text = "Sol %d / %d" % [sol, GameState.MAX_SOLS]
	if sol == 1:
		# Partida nueva: sincroniza las barras sin números flotantes y borra el historial.
		for stat in GameState.STAT_NAMES:
			_last_stats[stat] = GameState.get_stat(stat)
			_stat_history[stat] = []
		_new_words = 0
		_suppress_deltas = false
	summary_label.text = "\n".join(PackedStringArray(lines))
	summary_label.visible = not lines.is_empty()
	feedback_label.visible = false
	continue_button.visible = false
	_refresh_all()


func _on_event_presented(event: Dictionary, hint: String) -> void:
	feedback_label.visible = false
	continue_button.visible = false
	timer_label.visible = false

	# Pantalla derecha: la información del evento. Las opciones se enseñan en los móviles.
	title_label.text = str(event.get("title", ""))
	description_label.text = str(event.get("description", ""))
	var fact: String = str(event.get("nasa_fact", ""))
	nasa_fact_label.text = "NASA fact: " + fact
	nasa_fact_label.visible = not fact.is_empty()
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()

	# Foto de cómo estaba todo antes de decidir, para enseñar después qué cambió.
	for stat in GameState.STAT_NAMES:
		_stats_at_event[stat] = GameState.get_stat(stat)
	_progress_at_event = _progress_snapshot()

	waiting_label.text = _waiting_text()
	waiting_label.visible = true
	_debug_panel.close()
	decisions_view.scroll_vertical = 0

	mars_view.show_scene(_scene_for(event))
	_show_view(View.DECISIONS)
	_refresh_all()


func _waiting_text() -> String:
	if not PhoneBridge.active:
		return WAITING_TEXT
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


func _on_option_pressed(option_id: String) -> void:
	_debug_panel.close()
	TurnManager.submit_choice(option_id)


func _on_decision_resolved(option: Dictionary, feedback: String, success: bool) -> void:
	waiting_label.visible = false
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
