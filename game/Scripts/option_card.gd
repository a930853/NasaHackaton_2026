class_name OptionCard
extends PanelContainer
## Opción de una decisión. A diferencia de un Button, la tarjeta crece para que quepa
## TODO el texto (rol, descripción y costes), sin cortarlo.

signal chosen

const NORMAL_FILL: Color = Color(0.09, 0.14, 0.24)
const HOVER_FILL: Color = Color(0.14, 0.22, 0.38)
const BORDER: Color = Color(0.3, 0.45, 0.7)
const FONT_SIZE: int = 14

var disabled: bool = false:
	set(value):
		disabled = value
		modulate = Color(1, 1, 1, 0.5) if value else Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_POINTING_HAND

var _text_label: RichTextLabel
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat


func _init(bbcode_text: String = "") -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_normal_style = _make_style(NORMAL_FILL, 1)
	_hover_style = _make_style(HOVER_FILL, 2)
	add_theme_stylebox_override("panel", _normal_style)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text_label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_text_label.text = bbcode_text
	add_child(_text_label)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		chosen.emit()


func _on_hover(hovering: bool) -> void:
	if disabled:
		return
	add_theme_stylebox_override("panel", _hover_style if hovering else _normal_style)


func _make_style(fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BORDER
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
