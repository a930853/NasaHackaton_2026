class_name EndScreen
extends Control
## Pantalla de victoria o derrota, con la temática del juego: marco azul, fuente pixelada, el cohete y Marte
## en pixel art, los cuatro cascos de la tripulación y los objetivos con su marca.
##   Victoria: cohete aterrizado junto a un Marte que brilla, cascos de colores y confeti.
##   Derrota:  cohete caído junto a un Marte apagado, el icono de la barra que se agotó y cascos grises.
## Se rellena con show_result() y avisa con play_again / back_to_menu.

signal play_again
signal back_to_menu

const MARS: Texture2D = preload("res://Images/Marte.png")
const ROCKET_SHEET_PATH: String = "res://Images/Cohete.png"   # 2 fotogramas de 24x40 (solo cambia la llama)
const ROCKET_FRAME: Vector2 = Vector2(24.0, 40.0)
const ROCKET_BODY_HEIGHT: float = 29.0     # alto del cohete sin la llama

const PANEL_SIZE: Vector2 = Vector2(820.0, 600.0)
const WIN_COLOR: Color = Color(1.0, 0.87, 0.35)
const LOSE_COLOR: Color = Color(1.0, 0.45, 0.4)
const TEXT_COLOR: Color = Color(0.85, 0.92, 1.0)
const DIM_TEXT_COLOR: Color = Color(0.5, 0.57, 0.7)
const DONE_COLOR: Color = Color(0.4, 0.9, 0.5)
const OUTLINE_COLOR: Color = Color(0.02, 0.03, 0.08)
const POP_SECONDS: float = 0.5
const FLAME_SECONDS: float = 0.22
const CONFETTI_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2), Color(0.4, 0.9, 0.5), Color(1.0, 0.4, 0.4), Color(1.0, 1.0, 1.0), Color(0.4, 0.75, 1.0),
]

var _shade: ColorRect
var _vignette: ColorRect
var _panel: PanelContainer
var _column: VBoxContainer
var _confetti: CPUParticles2D
var _flame_timer: Timer
var _rocket_frames: Array[AtlasTexture] = []
var _rocket_rect: TextureRect
var _pulse: Tween = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	add_child(_Stars.new())

	_vignette = ColorRect.new()   # en la derrota late en rojo suave
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	add_child(_vignette)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", MenuStyle.NORMAL)   # el marco azul de los botones y las opciones
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	margin.add_child(_column)

	_confetti = _make_confetti()
	add_child(_confetti)

	_flame_timer = Timer.new()
	_flame_timer.wait_time = FLAME_SECONDS
	_flame_timer.timeout.connect(_on_flame_tick)
	add_child(_flame_timer)


## Enseña el resultado. `objectives` = [{"name": texto, "done": bool}]; `failed_stat` = la barra que se agotó
## ("health", "oxygen"...) en una derrota o "" si no se sabe.
func show_result(victory: bool, title: String, message: String, objectives: Array, score: int,
		words_text: String, failed_stat: String = "") -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()

	_shade.color = Color(0.02, 0.05, 0.13, 0.92) if victory else Color(0.09, 0.02, 0.04, 0.93)
	_column.add_child(_make_title(title, victory))
	_column.add_child(_make_picture(victory, failed_stat))
	_column.add_child(_make_crew(victory))
	_column.add_child(_make_message(message))
	_column.add_child(_make_objectives(objectives))
	_column.add_child(_make_score(score, victory))
	_column.add_child(_make_label(words_text, 14, DIM_TEXT_COLOR))
	_column.add_child(_make_buttons())

	_confetti.restart()            # borra el confeti que quedara de una partida anterior
	_confetti.emitting = victory
	_start_flame(victory)
	_start_vignette(not victory)
	visible = true
	_pop_in()


func hide_screen() -> void:
	visible = false
	_confetti.emitting = false
	_flame_timer.stop()
	if _pulse != null:
		_pulse.kill()
		_pulse = null


# ---------------------------------------------------------------- Piezas

func _make_title(text: String, victory: bool) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.FONT)
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", WIN_COLOR if victory else LOSE_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 8)
	return label


## Dibujo central: cohete + Marte (+ el icono de la barra que se agotó, si se perdió).
func _make_picture(victory: bool, failed_stat: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.custom_minimum_size = Vector2(0.0, 140.0)

	# Cohete: de pie y con la llama encendida al ganar; caído y apagado al perder.
	_rocket_frames.clear()
	_rocket_rect = null
	if ResourceLoader.exists(ROCKET_SHEET_PATH):
		var sheet: Texture2D = load(ROCKET_SHEET_PATH)
		for i in range(2):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			var height: float = ROCKET_FRAME.y if victory else ROCKET_BODY_HEIGHT
			frame.region = Rect2(ROCKET_FRAME.x * float(i), 0.0, ROCKET_FRAME.x, height)
			_rocket_frames.append(frame)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(120.0, 140.0)
		_rocket_rect = TextureRect.new()
		_rocket_rect.texture = _rocket_frames[0]
		_rocket_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_rocket_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rocket_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var scale_factor: float = 3.0
		_rocket_rect.size = _rocket_frames[0].get_size() * scale_factor
		_rocket_rect.pivot_offset = _rocket_rect.size * 0.5
		if victory:
			_rocket_rect.position = Vector2(24.0, 10.0)
		else:
			_rocket_rect.position = Vector2(14.0, 42.0)
			_rocket_rect.rotation_degrees = 72.0
			_rocket_rect.modulate = Color(0.7, 0.7, 0.75)
		holder.add_child(_rocket_rect)
		row.add_child(holder)

	# Marte: brilla al ganar y se apaga al perder.
	var mars := TextureRect.new()
	mars.texture = MARS
	mars.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mars.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mars.custom_minimum_size = Vector2(128.0, 128.0)
	mars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mars.modulate = Color(1.15, 1.1, 1.0) if victory else Color(0.45, 0.4, 0.42)
	row.add_child(mars)

	if not victory and StatIcon.BY_STAT.has(failed_stat):
		# El icono de la barra que se agotó, sobre la misma placa clara de los botones de la cabina y con borde rojo.
		var plate := PanelContainer.new()
		plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plate_style := StyleBoxFlat.new()
		plate_style.bg_color = Color(0.8, 0.86, 0.94)
		plate_style.border_color = Color(0.95, 0.27, 0.36)
		plate_style.set_border_width_all(4)
		plate_style.set_corner_radius_all(10)
		plate_style.set_content_margin_all(8)
		plate.add_theme_stylebox_override("panel", plate_style)
		var icon := TextureRect.new()
		icon.texture = StatIcon.BY_STAT[failed_stat]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(80.0, 80.0)
		plate.add_child(icon)
		row.add_child(plate)
	return row


## Los cuatro astronautas con el color de su rol (grises si se perdió).
func _make_crew(victory: bool) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for role in GameState.ROLES:
		var helmet := TextureRect.new()
		helmet.texture = CrewAvatar.get_helmet()
		helmet.custom_minimum_size = Vector2(48.0, 48.0)
		helmet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		helmet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		helmet.modulate = CrewAvatar.ROLE_ALBEDO.get(role, Color.WHITE) if victory else CrewAvatar.AWAY_ALBEDO
		row.add_child(helmet)
	return row


func _make_message(text: String) -> Label:
	var label := _make_label(text, 17, TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = PANEL_SIZE.x - 120.0
	return label


## Objetivos en dos columnas, cada uno con su marca (verde si se cumplió).
func _make_objectives(objectives: Array) -> Control:
	var holder := CenterContainer.new()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 6)
	holder.add_child(grid)
	for objective in objectives:
		var done: bool = bool(objective["done"])
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(_Mark.new(done))
		var label := _make_label(str(objective["name"]), 14, TEXT_COLOR if done else DIM_TEXT_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.add_child(label)
		grid.add_child(cell)
	return holder


func _make_score(score: int, victory: bool) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var caption := _make_label("SCORE", 16, DIM_TEXT_COLOR)
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(caption)
	var value := Label.new()
	value.text = str(score)
	value.add_theme_font_override("font", MenuStyle.FONT)
	value.add_theme_font_size_override("font_size", 34)
	value.add_theme_color_override("font_color", WIN_COLOR if victory else TEXT_COLOR)
	value.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	value.add_theme_constant_override("outline_size", 6)
	row.add_child(value)
	return row


func _make_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(260.0, 64.0)
	MenuStyle.apply(again, 18)
	again.pressed.connect(func() -> void:
		Events.sfx_requested.emit("click", 0.05)
		play_again.emit())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Back to menu"
	menu.custom_minimum_size = Vector2(260.0, 64.0)
	MenuStyle.apply(menu, 18)
	menu.pressed.connect(func() -> void:
		Events.sfx_requested.emit("click", 0.05)
		back_to_menu.emit())
	row.add_child(menu)
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# ---------------------------------------------------------------- Animaciones

## El panel aparece con un pequeño «pop».
func _pop_in() -> void:
	_panel.modulate.a = 0.0
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.scale = Vector2(0.88, 0.88)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, POP_SECONDS)
	tween.tween_property(_panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## La llama del cohete parpadea al ganar (dos fotogramas).
func _start_flame(victory: bool) -> void:
	_flame_timer.stop()
	if victory and _rocket_rect != null:
		_flame_timer.start()


func _on_flame_tick() -> void:
	if _rocket_rect == null or _rocket_frames.size() < 2:
		return
	_rocket_rect.texture = _rocket_frames[1] if _rocket_rect.texture == _rocket_frames[0] else _rocket_frames[0]


## En la derrota la pantalla late en rojo muy suave.
func _start_vignette(enabled: bool) -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	_vignette.color.a = 0.0
	if not enabled:
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_vignette, "color:a", 0.16, 1.6).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_vignette, "color:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)


func _make_confetti() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 90
	particles.lifetime = 5.0
	particles.preprocess = 2.0
	particles.position = Vector2(640.0, -10.0)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(660.0, 6.0)
	particles.direction = Vector2(0.0, 1.0)
	particles.spread = 18.0
	particles.gravity = Vector2(0.0, 90.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 110.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in range(CONFETTI_COLORS.size()):
		offsets.append(float(i) / float(CONFETTI_COLORS.size()))
		colors.append(CONFETTI_COLORS[i])
	ramp.offsets = offsets
	ramp.colors = colors
	particles.color_initial_ramp = ramp
	return particles


# ---------------------------------------------------------------- Dibujos pequeños

## Marca de un objetivo: un tick verde si se cumplió o una cajita apagada si no.
class _Mark extends Control:
	var done: bool = false

	func _init(is_done: bool = false) -> void:
		done = is_done
		custom_minimum_size = Vector2(22.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		if done:
			draw_rect(box, Color(0.08, 0.28, 0.16))
			draw_rect(box, Color(0.4, 0.9, 0.5), false, 2.0)
			draw_polyline(PackedVector2Array([Vector2(5.0, 11.5), Vector2(9.5, 16.0), Vector2(17.5, 6.0)]),
				Color(0.55, 1.0, 0.65), 3.0)
		else:
			draw_rect(box, Color(0.08, 0.1, 0.16))
			draw_rect(box, Color(0.3, 0.36, 0.48), false, 2.0)
			draw_line(Vector2(6.0, 11.0), Vector2(16.0, 11.0), Color(0.4, 0.46, 0.58), 2.0)


## Fondo de estrellas que parpadean.
class _Stars extends Control:
	const COUNT: int = 90
	var _points: Array[Vector3] = []   # x, y (0 a 1) y fase del parpadeo

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(COUNT):
			_points.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	# Solo se redibuja mientras la pantalla final está a la vista
	func _ready() -> void:
		set_process(is_visible_in_tree())

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var seconds: float = Time.get_ticks_msec() / 1000.0
		for point in _points:
			var twinkle: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(seconds * 1.8 + point.z))
			var side: float = 3.0 if int(point.z * 10.0) % 7 == 0 else 2.0
			draw_rect(Rect2(point.x * size.x, point.y * size.y, side, side), Color(1, 1, 1, twinkle))
