extends Control
## Pantalla principal de la partida. Solo muestra el estado y reenvía las
## decisiones al TurnManager; no calcula ninguna consecuencia.
## Hoy las decisiones se toman con botones; más adelante llegarán de los móviles/NFC
## y bastará con llamar igualmente a TurnManager.submit_choice().
##
## Texto del juego: inglés sencillo para niños de 7 a 12 años.

const STAT_LABELS: Dictionary = {
	"health": "Health", "oxygen": "Oxygen", "energy": "Energy", "integrity": "Base strength",
}
const STAT_COLORS: Dictionary = {
	"health": Color(0.35, 0.8, 0.45), "oxygen": Color(0.4, 0.7, 1.0),
	"energy": Color(1.0, 0.8, 0.25), "integrity": Color(0.75, 0.75, 0.8),
}
const LOW_STAT_THRESHOLD: int = 30
const LOW_STAT_COLOR: Color = Color(1.0, 0.3, 0.3)

const ROLE_LABELS: Dictionary = {
	"engineer": "Engineer", "biologist": "Biologist", "doctor": "Doctor", "generalist": "Commander",
}
const ROLE_COLORS: Dictionary = {
	"engineer": Color(0.45, 0.65, 1.0), "biologist": Color(0.45, 0.9, 0.55),
	"doctor": Color(1.0, 0.45, 0.45), "generalist": Color(1.0, 0.85, 0.35),
}
const GENERAL_LABEL: String = "Everyone"

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

@onready var sol_label: Label = %SolLabel
@onready var stats_box: HBoxContainer = %StatsBox
@onready var objectives_label: Label = %ObjectivesLabel
@onready var conditions_label: Label = %ConditionsLabel
@onready var summary_label: Label = %SummaryLabel
@onready var title_label: Label = %TitleLabel
@onready var timer_label: Label = %TimerLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var nasa_fact_label: Label = %NasaFactLabel
@onready var hint_label: Label = %HintLabel
@onready var options_box: VBoxContainer = %OptionsBox
@onready var feedback_label: RichTextLabel = %FeedbackLabel
@onready var continue_button: Button = %ContinueButton
@onready var glossary_button: Button = %GlossaryButton
@onready var earth_help_button: Button = %EarthHelpButton
@onready var debug_flare_button: Button = %DebugFlareButton
@onready var toast_label: Label = %ToastLabel

var _stat_widgets: Dictionary = {}   # stat -> {"label": Label, "bar": ProgressBar}
var _glossary_panel: GlossaryPanel
var _earth_panel: UiOverlay
var _end_panel: UiOverlay
var _toast_tween: Tween = null

# --- Para enseñar las consecuencias en pantalla ---
var _last_stats: Dictionary = {}          # barras la última vez que se dibujaron
var _stats_at_event: Dictionary = {}      # barras al aparecer el evento actual
var _progress_at_event: Dictionary = {}   # progreso al aparecer el evento actual
var _suppress_deltas: bool = false        # true al reiniciar: no mostrar números flotantes


func _ready() -> void:
	_build_stat_widgets()
	_build_overlays()
	toast_label.modulate.a = 0.0

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

	continue_button.pressed.connect(TurnManager.continue_after_resolution)
	glossary_button.pressed.connect(_glossary_panel.open)
	earth_help_button.pressed.connect(_open_earth_panel)
	debug_flare_button.pressed.connect(TurnManager.simulate_solar_flare)

	TurnManager.start_game()


# --------------------------------------------------------------- Construcción

func _build_stat_widgets() -> void:
	for stat in GameState.STAT_NAMES:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = GameState.STAT_MAX
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(140, 16)
		box.add_child(label)
		box.add_child(bar)
		stats_box.add_child(box)
		_stat_widgets[stat] = {"label": label, "bar": bar}


func _build_overlays() -> void:
	_glossary_panel = GlossaryPanel.new()
	add_child(_glossary_panel)

	_earth_panel = UiOverlay.new(Vector2(640, 420))
	add_child(_earth_panel)

	_end_panel = UiOverlay.new(Vector2(760, 520))
	add_child(_end_panel)


# ------------------------------------------------------------------- Refrescos

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_objectives()
	_refresh_conditions()
	_refresh_earth_help_button()


func _refresh_stats() -> void:
	for stat in GameState.STAT_NAMES:
		var value: int = GameState.get_stat(stat)
		var widgets: Dictionary = _stat_widgets[stat]
		(widgets["label"] as Label).text = "%s: %d" % [STAT_LABELS[stat], value]
		var bar: ProgressBar = widgets["bar"]
		bar.value = value
		bar.modulate = LOW_STAT_COLOR if value <= LOW_STAT_THRESHOLD else STAT_COLORS[stat]

		# Cada cambio de una barra sube flotando junto a ella (+15 verde, -10 rojo).
		if _last_stats.has(stat) and not _suppress_deltas:
			var delta: int = value - int(_last_stats[stat])
			if delta != 0:
				_spawn_delta(bar, delta)
		_last_stats[stat] = value


## Número flotante junto a una barra que sube y se desvanece.
func _spawn_delta(bar: ProgressBar, delta: int) -> void:
	var popup := Label.new()
	popup.text = "%+d" % delta
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if delta > 0 else Color(1.0, 0.4, 0.4))
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 6)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	var start: Vector2 = bar.global_position - global_position + Vector2(randf_range(0.0, bar.size.x * 0.6), 18.0)
	popup.position = start
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", start.y + 60.0, 1.4)
	tween.tween_property(popup, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)


func _refresh_objectives() -> void:
	var alert_text: String = " (early warning ON!)" if GameState.seismic_alert_active else ""
	objectives_label.text = "Goals  |  Harvests %d/%d  |  Rover: %s  |  Sensors %d/%d%s  |  MOXIE %d%%" % [
		GameState.harvests_completed, GameState.HARVEST_GOAL,
		"free" if GameState.rover_rescued else "stuck",
		GameState.sensors_placed, GameState.SENSOR_GOAL, alert_text,
		GameState.moxie_progress]
	glossary_button.text = "Science Words Book (%d)" % GameState.unlocked_terms.size()


func _refresh_conditions() -> void:
	var parts: Array[String] = []
	for condition in GameState.active_conditions:
		var sols_left: int = int(condition["sols_left"])
		parts.append("%s: %d Sol%s left" % [
			condition.get("name", condition["id"]), sols_left, "" if sols_left == 1 else "s"])
	for waiting in TurnManager.waiting_events():
		parts.append("Waiting for Earth: %s (Sol %d)" % [waiting["title"], waiting["return_sol"]])
	conditions_label.text = "Problems going on: " + (" • ".join(PackedStringArray(parts)) if not parts.is_empty() else "none")


func _refresh_earth_help_button() -> void:
	var available: bool = TurnManager.can_request_earth_help()
	earth_help_button.disabled = not available
	if available:
		earth_help_button.tooltip_text = "Ask Earth for a hint. You can do it once per Sol."
	elif GameState.earth_help_blocked():
		earth_help_button.tooltip_text = "The solar storm is blocking radio messages."
	else:
		earth_help_button.tooltip_text = "Not now. Earth cannot help with emergencies, and you can ask only once per Sol."


# -------------------------------------------------------- Señales del TurnManager

func _on_sol_started(sol: int, lines: Array) -> void:
	sol_label.text = "Sol %d / %d" % [sol, GameState.MAX_SOLS]
	if sol == 1:
		# Partida nueva: sincroniza las barras sin mostrar números flotantes.
		for stat in GameState.STAT_NAMES:
			_last_stats[stat] = GameState.get_stat(stat)
		_suppress_deltas = false
	summary_label.text = "\n".join(PackedStringArray(lines))
	summary_label.visible = not lines.is_empty()
	_clear_options()
	feedback_label.visible = false
	continue_button.visible = false
	_refresh_all()


func _on_event_presented(event: Dictionary, hint: String) -> void:
	_clear_options()
	feedback_label.visible = false
	continue_button.visible = false
	timer_label.visible = false

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

	for option in event.get("options", []):
		options_box.add_child(_make_option_button(option))
	_refresh_all()


func _make_option_button(option: Dictionary) -> Button:
	var role: Variant = option.get("role")
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 92)

	# El texto va en un RichTextLabel para colorear SOLO la etiqueta del rol.
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	var role_tag: String
	if role == null:
		role_tag = "[b]%s:[/b]" % GENERAL_LABEL
	else:
		var hex: String = (ROLE_COLORS.get(role, Color.WHITE) as Color).to_html(false)
		role_tag = "[color=#%s][b]%s:[/b][/color]" % [hex, ROLE_LABELS.get(role, role)]
	rich.text = "%s %s\n%s" % [role_tag, option["label"], describe_option(option)]
	button.add_child(rich)

	button.pressed.connect(_on_option_pressed.bind(str(option["id"])))
	return button


# ---- Costes y probabilidad de éxito visibles antes de elegir ----

## Segunda línea de cada botón: lo que cuesta la opción. (La probabilidad de éxito no se enseña.)
func describe_option(option: Dictionary) -> String:
	var now_costs: Array[String] = _cost_parts(option.get("effects", {}))
	var text: String = "Costs: " + (", ".join(PackedStringArray(now_costs)) if not now_costs.is_empty() else "nothing")

	for delayed in option.get("delayed", []):
		var later: Array[String] = _cost_parts(delayed.get("effects", {}))
		if not later.is_empty():
			text += "  +  Later: %s (in %d Sol%s)" % [
				", ".join(PackedStringArray(later)), int(delayed.get("after_sols", 1)),
				"" if int(delayed.get("after_sols", 1)) == 1 else "s"]

	var condition: Dictionary = option.get("start_condition", {})
	var morning_costs: Array[String] = []
	if condition.has("sequence"):
		for step in condition["sequence"]:
			morning_costs.append(", ".join(PackedStringArray(_cost_parts(step))))
		if not morning_costs.is_empty():
			text += "  +  Each morning: " + "  then  ".join(PackedStringArray(morning_costs))
	elif condition.has("daily"):
		var daily: Array[String] = _cost_parts(condition["daily"])
		if not daily.is_empty():
			text += "  +  Each morning for %d Sols: %s" % [int(condition.get("sols", 1)), ", ".join(PackedStringArray(daily))]

	return text


## Solo los efectos negativos (lo que se gasta), en el orden fijo de las barras.
func _cost_parts(effects: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	for stat in GameState.STAT_NAMES:
		var amount: int = int(effects.get(stat, 0))
		if amount < 0:
			parts.append("%s %d" % [STAT_LABELS[stat], amount])
	return parts


func _on_option_pressed(option_id: String) -> void:
	TurnManager.submit_choice(option_id)


func _on_decision_resolved(option: Dictionary, feedback: String, success: bool) -> void:
	for child in options_box.get_children():
		if child is Button:
			(child as Button).disabled = true
			(child as Button).modulate = Color(1, 1, 1, 0.55)  # atenúa también el texto
	timer_label.visible = false
	var banner: String = ""
	if not option.is_empty():
		banner = SUCCESS_BANNER if success else FAIL_BANNER
	feedback_label.text = banner + feedback + _change_summary()
	feedback_label.visible = true
	continue_button.visible = true
	continue_button.grab_focus()
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


func _clear_options() -> void:
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------ Libro / avisos

func _on_term_unlocked(_term_id: String, title: String) -> void:
	toast_label.text = "New word added to the Science Words Book: %s" % title
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	_refresh_objectives()


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
