class_name EarthHelpFace
extends HBoxContainer
## Cara del botón «Ask Earth for help»: la radio de la base.
## A la izquierda, la Tierra en pixel art con las ondas de radio (o la batería recargándose); a la derecha, el
## nombre en la fuente del juego y una línea de estado de color: lista, recargando, sin señal o no disponible.
## Uso: EarthHelpFace.style_button(boton), añadir la cara como hija y llamar a set_state() cuando cambie algo.

enum State { READY, RECHARGING, NO_SIGNAL, NOT_NOW }

const EARTH: Texture2D = preload("res://Images/tierra.png")
const BUTTON_HEIGHT: float = 58.0
const FILL: Color = Color(0.04, 0.07, 0.14)
const BORDER: Color = Color(0.28, 0.42, 0.68)
const BORDER_HOVER: Color = Color(0.5, 0.72, 1.0)
const BORDER_PRESSED: Color = Color(1.0, 0.86, 0.35)
const OFF_FILL: Color = Color(0.03, 0.04, 0.08)
const OFF_BORDER: Color = Color(0.16, 0.2, 0.3)
const TITLE_COLOR: Color = Color(1.0, 0.93, 0.7)
const STATE_COLORS: Dictionary = {
	State.READY: Color(0.45, 1.0, 0.6),
	State.RECHARGING: Color(1.0, 0.78, 0.3),
	State.NO_SIGNAL: Color(1.0, 0.45, 0.4),
	State.NOT_NOW: Color(0.5, 0.57, 0.7),
}

var _dish: _Dish
var _title: Label
var _status: Label


## Quita el aspecto gris de Godot al botón y le pone la caja oscura de borde azul de la pantalla de la cabina.
static func style_button(button: Button) -> void:
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.add_theme_stylebox_override("normal", _box(FILL, BORDER, 2))
	button.add_theme_stylebox_override("hover", _box(Color(0.08, 0.13, 0.24), BORDER_HOVER, 2))
	button.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.15, 0.26), BORDER_PRESSED, 3))
	button.add_theme_stylebox_override("disabled", _box(OFF_FILL, OFF_BORDER, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)

	_dish = _Dish.new()
	add_child(_dish)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 1)
	add_child(texts)

	_title = Label.new()
	_title.text = "ASK EARTH FOR HELP"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override("font", MenuStyle.FONT)
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08))
	_title.add_theme_constant_override("outline_size", 4)
	texts.add_child(_title)

	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 12)
	texts.add_child(_status)

	set_state(State.NOT_NOW)


## `sols_left` y `sols_total` solo cuentan al recargar: cuántos Sols faltan y cuántos dura la recarga entera.
func set_state(state: int, sols_left: int = 0, sols_total: int = 1) -> void:
	var color: Color = STATE_COLORS[state]
	match state:
		State.READY:
			_status.text = "Radio ready: get a hint from Mission Control"
		State.RECHARGING:
			_status.text = "Radio recharging: ready in %d Sol%s" % [sols_left, "" if sols_left == 1 else "s"]
		State.NO_SIGNAL:
			_status.text = "No signal: the solar storm blocks the radio"
		_:
			_status.text = "Not now: Earth cannot help with this"
	_status.add_theme_color_override("font_color", color)
	_title.add_theme_color_override("font_color", TITLE_COLOR if state == State.READY else Color(0.55, 0.6, 0.7))
	_dish.show_state(state, color, sols_left, sols_total)


static func _box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(8)
	return box


## La Tierra y lo que sale de ella: ondas de radio que avanzan (lista), una batería que se llena (recargando),
## las ondas tachadas (sin señal) o apagadas (no disponible).
class _Dish extends Control:
	const PLANET: float = 38.0
	const WAVES: int = 3
	const WAVE_SECONDS: float = 0.28

	var _state: int = State.NOT_NOW
	var _color: Color = Color.WHITE
	var _left: int = 0
	var _total: int = 1

	func _init() -> void:
		custom_minimum_size = Vector2(PLANET + 34.0, PLANET + 4.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func show_state(state: int, color: Color, sols_left: int, sols_total: int) -> void:
		_state = state
		_color = color
		_left = sols_left
		_total = maxi(sols_total, 1)
		set_process(state == State.READY and is_visible_in_tree())   # solo se anima cuando la radio está lista
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(_state == State.READY and is_visible_in_tree())

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var planet := Rect2(0.0, (size.y - PLANET) * 0.5, PLANET, PLANET)
		var dim: bool = _state != State.READY
		draw_texture_rect(EARTH, planet, false, Color(0.55, 0.58, 0.66) if dim else Color.WHITE)

		if _state == State.RECHARGING:
			_draw_battery(Vector2(PLANET + 6.0, size.y * 0.5))
			return

		# Ondas de radio: arcos que se encienden de dentro hacia fuera
		var origin := Vector2(PLANET - 3.0, size.y * 0.5)
		var lit: int = WAVES
		if _state == State.READY:
			lit = int(Time.get_ticks_msec() / 1000.0 / WAVE_SECONDS) % (WAVES + 2)
		for i in range(WAVES):
			var wave_color: Color = _color if _state == State.READY else Color(0.3, 0.35, 0.46)
			if _state == State.READY and i >= lit:
				wave_color = Color(0.2, 0.3, 0.45)
			draw_arc(origin, 11.0 + 8.0 * float(i), -PI * 0.28, PI * 0.28, 8, wave_color, 3.0)

		if _state == State.NO_SIGNAL:   # sin señal: una cruz roja sobre las ondas
			var middle := Vector2(PLANET + 18.0, size.y * 0.5)
			draw_line(middle + Vector2(-8.0, -8.0), middle + Vector2(8.0, 8.0), _color, 4.0)
			draw_line(middle + Vector2(-8.0, 8.0), middle + Vector2(8.0, -8.0), _color, 4.0)

	## Batería con un trozo por cada Sol de recarga; se llenan los que ya han pasado.
	func _draw_battery(left_middle: Vector2) -> void:
		var body := Rect2(left_middle + Vector2(0.0, -9.0), Vector2(24.0, 18.0))
		draw_rect(body, Color(0.03, 0.04, 0.08))
		draw_rect(body, _color, false, 2.0)
		draw_rect(Rect2(body.end.x, left_middle.y - 4.0, 3.0, 8.0), _color)
		var gap: float = 2.0
		var cell: float = (body.size.x - 4.0 - gap * float(_total - 1)) / float(_total)
		for i in range(_total - _left):
			draw_rect(Rect2(body.position.x + 2.0 + (cell + gap) * float(i), body.position.y + 4.0, cell, 10.0), _color)
