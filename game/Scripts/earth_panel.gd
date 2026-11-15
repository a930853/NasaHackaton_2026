class_name EarthPanel
extends Control
## Ventana «Ask Earth for help», con la temática del juego: marco azul, fuente pixelada y un dibujo de Marte y la
## Tierra unidos por la señal de radio (el mensaje va hacia la Tierra y la respuesta vuelve en ámbar).
## Debajo, una tarjeta por cada forma de pedir ayuda, con lo que cuesta y cuánto tarda la respuesta.
## Se abre con open() y avisa con `chosen` (id de la opción). Cancelar o Escape la cierran sin elegir.

signal chosen(choice_id: String)

const MARS: Texture2D = preload("res://Images/Marte.png")
const EARTH: Texture2D = preload("res://Images/tierra.png")
const ENERGY_ICON: Texture2D = preload("res://Images/Energia.png")

const PANEL_WIDTH: float = 760.0
const POP_SECONDS: float = 0.3
const FILL: Color = Color(0.04, 0.07, 0.14)
const BORDER: Color = Color(0.28, 0.42, 0.68)
const BORDER_HOVER: Color = Color(1.0, 0.86, 0.35)
const TITLE_COLOR: Color = Color(1.0, 0.87, 0.35)
const TEXT_COLOR: Color = Color(0.86, 0.92, 1.0)
const DIM_TEXT_COLOR: Color = Color(0.55, 0.63, 0.78)
const OUTLINE_COLOR: Color = Color(0.02, 0.03, 0.08)
const COST_COLOR: Color = Color(1.0, 0.66, 0.15)
const FREE_COLOR: Color = Color(0.45, 1.0, 0.6)
const TIME_COLOR: Color = Color(0.5, 0.78, 1.0)

var _panel: PanelContainer
var _column: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.09, 0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.add_theme_stylebox_override("panel", MenuStyle.NORMAL)   # el marco azul de los botones del menú
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	margin.add_child(_column)


## `options` = [{id, title, text, energy_cost, delay_sols}]. `million_km` y `minutes`: distancia a la Tierra y lo
## que tarda un mensaje de radio. `cooldown_sols`: lo que tarda la radio en recargarse después de usarla.
func open(options: Array, million_km: int, minutes: int, cooldown_sols: int) -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()

	_column.add_child(_make_title("ASK EARTH FOR HELP"))
	_column.add_child(_Link.new(million_km, minutes))
	_column.add_child(_make_text(
		"Mars is very far from home! Today's problem will wait and you will move on to the next Sol. "
		+ "When Earth answers, the problem comes back with a hint.", 15, TEXT_COLOR))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	for option in options:
		cards.add_child(_make_card(option))
	_column.add_child(cards)

	_column.add_child(_make_text(
		"After a message, the radio needs %d Sols to recharge." % cooldown_sols, 13, DIM_TEXT_COLOR))

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(220.0, 0.0)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.focus_mode = Control.FOCUS_NONE
	MenuStyle.apply(cancel, 14)
	cancel.pressed.connect(func() -> void:
		Events.sfx_requested.emit("click", 0.05)
		close())
	_column.add_child(cancel)

	visible = true
	_pop_in()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------------- Piezas

func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MenuStyle.FONT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", TITLE_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _make_text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Tarjeta de una forma de pedir ayuda: nombre, explicación, lo que cuesta y cuándo llega la respuesta.
func _make_card(option: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0.0, 176.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _box(FILL, BORDER, 2, 10))
	card.add_theme_stylebox_override("hover", _box(Color(0.08, 0.13, 0.24), BORDER_HOVER, 3, 10))
	card.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.18, 0.3), BORDER_HOVER, 3, 10))
	card.pressed.connect(func() -> void:
		Events.sfx_requested.emit("click", 0.05)
		close()
		chosen.emit(str(option["id"])))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_right = -12.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var title := Label.new()
	title.text = str(option["title"]).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", MenuStyle.FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
	title.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	title.add_theme_constant_override("outline_size", 4)
	column.add_child(title)

	column.add_child(_make_text(str(option["text"]), 14, TEXT_COLOR))

	var chips := VBoxContainer.new()   # uno encima del otro: la fuente pixelada es ancha y no cabrían en fila
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 6)
	column.add_child(chips)

	var cost: int = int(option["energy_cost"])
	if cost > 0:
		chips.add_child(_make_chip("Energy -%d" % cost, COST_COLOR, ENERGY_ICON))
	else:
		chips.add_child(_make_chip("Free", FREE_COLOR))
	var delay: int = int(option["delay_sols"])
	chips.add_child(_make_chip("Answer in %d Sol%s" % [delay, "" if delay == 1 else "s"], TIME_COLOR))
	return card


## Etiqueta pequeña de color (coste o tiempo), con un icono opcional sobre una plaquita clara.
func _make_chip(text: String, color: Color, icon: Texture2D = null) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = _box(Color(color.r, color.g, color.b, 0.12), color, 2, 6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	chip.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)

	if icon != null:
		# El logo va relleno de su color (como en las barras de la cabina), sin placa blanca.
		var picture := StatIcon.new(icon, color)
		picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
		picture.custom_minimum_size = Vector2(30.0, 30.0)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)

	var label := Label.new()
	label.text = text.to_upper()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", MenuStyle.FONT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	return chip


func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


## La ventana aparece con un pequeño «pop».
func _pop_in() -> void:
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame   # el panel aún no tiene su tamaño final
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, POP_SECONDS)
	tween.tween_property(_panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Dibujo de la señal

## Marte a la izquierda, la Tierra a la derecha y, entre los dos, el camino de la señal de radio: un mensaje
## azul viaja hasta la Tierra y después la respuesta vuelve en ámbar. Encima, la distancia; debajo, lo que tarda.
class _Link extends Control:
	const HEIGHT: float = 150.0
	const PLANET: float = 84.0
	const SIDE: float = 44.0
	const TRIP_SECONDS: float = 2.2
	const STAR_COUNT: int = 46
	const OUT_COLOR: Color = Color(0.45, 0.85, 1.0)
	const BACK_COLOR: Color = Color(1.0, 0.8, 0.3)

	var _distance_text: String
	var _time_text: String
	var _stars: Array[Vector3] = []   # x, y (0 a 1) y fase del parpadeo

	func _init(million_km: int = 0, minutes: int = 0) -> void:
		_distance_text = "%d MILLION KM" % million_km
		_time_text = "A radio message takes about %d minutes" % minutes
		custom_minimum_size = Vector2(0.0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		for i in range(STAR_COUNT):
			_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())   # solo se anima con la ventana abierta

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var seconds: float = Time.get_ticks_msec() / 1000.0
		var sky := StyleBoxFlat.new()
		sky.bg_color = Color(0.02, 0.03, 0.08)
		sky.border_color = Color(0.28, 0.42, 0.68)
		sky.set_border_width_all(2)
		sky.set_corner_radius_all(10)
		draw_style_box(sky, Rect2(Vector2.ZERO, size))

		for star in _stars:
			var twinkle: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(seconds * 1.8 + star.z))
			var side: float = 3.0 if int(star.z * 10.0) % 6 == 0 else 2.0
			draw_rect(Rect2(8.0 + star.x * (size.x - 20.0), 8.0 + star.y * (size.y - 20.0), side, side),
				Color(1, 1, 1, twinkle * 0.8))

		var planet_y: float = 20.0
		var middle_y: float = planet_y + PLANET * 0.5
		var mars_rect := Rect2(SIDE, planet_y, PLANET, PLANET)
		var earth_rect := Rect2(size.x - SIDE - PLANET, planet_y, PLANET, PLANET)
		draw_texture_rect(MARS, mars_rect, false)
		draw_texture_rect(EARTH, earth_rect, false)

		var pixel_font: Font = MenuStyle.FONT
		var text_font: Font = get_theme_default_font()
		_centered(pixel_font, "MARS", mars_rect.get_center().x, planet_y + PLANET + 22.0, 11, Color(1.0, 0.6, 0.4))
		_centered(pixel_font, "EARTH", earth_rect.get_center().x, planet_y + PLANET + 22.0, 11, Color(0.5, 0.8, 1.0))

		# Camino de puntos entre los dos planetas
		var from_x: float = mars_rect.end.x + 16.0
		var to_x: float = earth_rect.position.x - 16.0
		var x: float = from_x
		while x <= to_x:
			draw_rect(Rect2(x - 1.5, middle_y - 1.5, 3.0, 3.0), Color(0.3, 0.42, 0.62))
			x += 14.0

		# El mensaje va (azul) y la respuesta vuelve (ámbar)
		var cycle: float = fmod(seconds, TRIP_SECONDS * 2.0)
		var going: bool = cycle < TRIP_SECONDS
		var progress: float = (cycle if going else cycle - TRIP_SECONDS) / TRIP_SECONDS
		var packet_x: float = lerpf(from_x, to_x, progress if going else 1.0 - progress)
		var packet_color: Color = OUT_COLOR if going else BACK_COLOR
		var direction: float = 1.0 if going else -1.0
		for i in range(4):   # el paquete y su estela
			var alpha: float = 1.0 - 0.25 * float(i)
			var side: float = 9.0 - 2.0 * float(i)
			var trail_x: float = packet_x - direction * 12.0 * float(i)
			if trail_x < from_x - 4.0 or trail_x > to_x + 4.0:
				continue
			draw_rect(Rect2(trail_x - side * 0.5, middle_y - side * 0.5, side, side),
				Color(packet_color.r, packet_color.g, packet_color.b, alpha))

		var center_x: float = (from_x + to_x) * 0.5
		_centered(pixel_font, _distance_text, center_x, middle_y - 22.0, 14, Color(1.0, 0.93, 0.7))
		_centered(text_font, _time_text, center_x, middle_y + 34.0, 14, Color(0.7, 0.85, 1.0))

	func _centered(font: Font, text: String, center_x: float, baseline_y: float, font_size: int, color: Color) -> void:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := Vector2(roundf(center_x - width * 0.5), baseline_y)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02, 0.03, 0.08))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
