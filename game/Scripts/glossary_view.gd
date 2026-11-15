class_name GlossaryView
extends HBoxContainer
## Libro de palabras científicas dentro de la pantalla de la cabina.
## Izquierda: una rejilla de tarjetas, una por palabra, con su dibujo en pixel art (las que aún no se han
## descubierto salen apagadas con un «?»). Derecha: el dibujo grande, el título, la explicación y el dato de la NASA.
## Los dibujos son res://Images/Glossary/<id del término>.png (los genera tools/make_glossary_icons.py).

const ICON_DIR: String = "res://Images/Glossary/"
const BOOK_ICON: String = "res://Images/Libro.png"
const COLUMNS: int = 3
const CARD_SIZE: Vector2 = Vector2(58.0, 58.0)
const GRID_WIDTH: float = 196.0
const DETAIL_ICON_SIZE: float = 80.0

const FILL: Color = Color(0.04, 0.07, 0.14)
const BORDER: Color = Color(0.28, 0.42, 0.68)
const BORDER_HOVER: Color = Color(0.5, 0.72, 1.0)
const BORDER_SELECTED: Color = Color(1.0, 0.86, 0.35)
const BORDER_NEW: Color = Color(0.95, 0.6, 0.2)
const LOCKED_FILL: Color = Color(0.03, 0.04, 0.08)
const LOCKED_BORDER: Color = Color(0.16, 0.2, 0.3)
const TITLE_COLOR: Color = Color(1.0, 0.93, 0.7)
const TEXT_COLOR: Color = Color(0.86, 0.92, 1.0)
const FACT_COLOR: Color = Color(0.6, 0.85, 1.0)

static var _seen: Array[String] = []   # palabras ya miradas (las nuevas llevan un borde naranja)

var _counter: Label
var _grid: GridContainer
var _grid_scroll: ScrollContainer
var _group: ButtonGroup
var _icon: TextureRect
var _title: Label
var _definition: RichTextLabel
var _fact_box: PanelContainer
var _fact: RichTextLabel
var _selected: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 12)
	_build_grid_column()
	_build_detail_column()


func _ready() -> void:
	GlossaryManager.term_unlocked.connect(_on_term_unlocked)


# ---------------------------------------------------------------- Construcción

func _build_grid_column() -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(GRID_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_counter = Label.new()
	_counter.add_theme_font_override("font", MenuStyle.FONT)
	_counter.add_theme_font_size_override("font_size", 13)
	_counter.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(_counter)

	var scroll := ScrollContainer.new()
	_grid_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	_group = ButtonGroup.new()


func _build_detail_column() -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	# Dibujo grande sobre la misma placa clara de los botones de la cabina + título al lado
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)

	var plate := PanelContainer.new()
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", _plate_style())
	head.add_child(plate)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(DETAIL_ICON_SIZE, DETAIL_ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_child(_icon)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", MenuStyle.FONT)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 4)
	head.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	_definition = RichTextLabel.new()
	_definition.bbcode_enabled = true
	_definition.fit_content = true
	_definition.scroll_active = false
	_definition.add_theme_font_size_override("normal_font_size", 15)
	_definition.add_theme_color_override("default_color", TEXT_COLOR)
	body.add_child(_definition)

	_fact_box = PanelContainer.new()
	_fact_box.add_theme_stylebox_override("panel", _box(FILL, BORDER, 2, 8, 8))
	body.add_child(_fact_box)
	var fact_column := VBoxContainer.new()
	fact_column.add_theme_constant_override("separation", 4)
	_fact_box.add_child(fact_column)
	var caption := Label.new()
	caption.text = "NASA FACT"
	caption.add_theme_font_override("font", MenuStyle.FONT)
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", BORDER_NEW)
	fact_column.add_child(caption)
	_fact = RichTextLabel.new()
	_fact.bbcode_enabled = true
	_fact.fit_content = true
	_fact.scroll_active = false
	_fact.add_theme_font_size_override("normal_font_size", 14)
	_fact.add_theme_color_override("default_color", FACT_COLOR)
	fact_column.add_child(_fact)


# ---------------------------------------------------------------- Contenido

## Vuelve a dibujar la rejilla con todas las palabras y enseña la última que se descubrió.
func refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var unlocked: Array[String] = GlossaryManager.get_unlocked_ids()
	_counter.text = "%d / %d" % [unlocked.size(), GlossaryManager.total_terms()]
	for term_id in GlossaryManager.get_all_ids():
		_grid.add_child(_make_card(term_id, term_id in unlocked))

	if unlocked.is_empty():
		_show_empty()
		return
	var newest: String = GameState.unlocked_terms[GameState.unlocked_terms.size() - 1]
	_select(newest if _selected.is_empty() or not (_selected in unlocked) else _selected)


## Tarjeta de una palabra: su dibujo (o un «?» si aún no se descubrió).
func _make_card(term_id: String, unlocked: bool) -> Button:
	var card := Button.new()
	card.set_meta("term_id", term_id)
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.toggle_mode = true
	card.button_group = _group
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_constant_override("icon_max_width", 40)
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if unlocked:
		card.icon = _icon_for(term_id)
		card.tooltip_text = str(GlossaryManager.get_term(term_id).get("title", term_id))
		var fresh: bool = not (term_id in _seen)
		card.add_theme_stylebox_override("normal", _box(FILL, BORDER_NEW if fresh else BORDER, 2, 8, 4))
		card.add_theme_stylebox_override("hover", _box(Color(0.08, 0.13, 0.24), BORDER_HOVER, 2, 8, 4))
		var selected_box: StyleBoxFlat = _box(Color(0.1, 0.15, 0.26), BORDER_SELECTED, 3, 8, 4)
		card.add_theme_stylebox_override("pressed", selected_box)
		card.add_theme_stylebox_override("hover_pressed", selected_box)
		card.pressed.connect(_select.bind(term_id))
	else:
		card.text = "?"
		card.disabled = true
		card.tooltip_text = "???"
		card.add_theme_font_override("font", MenuStyle.FONT)
		card.add_theme_font_size_override("font_size", 22)
		card.add_theme_color_override("font_disabled_color", Color(0.22, 0.27, 0.38))
		card.add_theme_stylebox_override("disabled", _box(LOCKED_FILL, LOCKED_BORDER, 2, 8, 4))
	return card


func _select(term_id: String) -> void:
	_selected = term_id
	if not (term_id in _seen):
		_seen.append(term_id)
	var term: Dictionary = GlossaryManager.get_term(term_id)
	_icon.texture = _icon_for(term_id)
	_title.text = str(term.get("title", term_id))
	_definition.text = str(term.get("definition", ""))
	_fact.text = str(term.get("nasa_fact", ""))
	_fact_box.visible = true
	# La tarjeta elegida queda marcada (y deja de ser «nueva») y se hace visible en la rejilla.
	for child in _grid.get_children():
		var card: Button = child as Button
		if card == null or card.disabled:
			continue
		var is_selected: bool = str(card.get_meta("term_id")) == term_id
		card.set_pressed_no_signal(is_selected)
		if is_selected:
			card.add_theme_stylebox_override("normal", _box(FILL, BORDER, 2, 8, 4))
			_show_card.call_deferred(term_id)


## Desplaza la rejilla hasta la tarjeta de esa palabra (se busca al llamar: la rejilla pudo reconstruirse).
func _show_card(term_id: String) -> void:
	await get_tree().process_frame   # la rejilla se acaba de reconstruir: espera a que tenga su tamaño
	for child in _grid.get_children():
		if child.has_meta("term_id") and str(child.get_meta("term_id")) == term_id:
			_grid_scroll.ensure_control_visible(child as Control)
			return


func _show_empty() -> void:
	_selected = ""
	_icon.texture = _book_texture()
	_title.text = "WORD BOOK"
	_definition.text = "You have not found any words yet. They appear as the game goes on!"
	_fact_box.visible = false


func _icon_for(term_id: String) -> Texture2D:
	var path: String = ICON_DIR + term_id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return _book_texture()   # sin dibujo (aún no importado o término nuevo): el libro


func _book_texture() -> Texture2D:
	return load(BOOK_ICON) if ResourceLoader.exists(BOOK_ICON) else null


func _on_term_unlocked(_term_id: String, _title_text: String) -> void:
	if is_visible_in_tree():
		refresh()


# ---------------------------------------------------------------- Estilos

func _box(fill: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box


## Placa clara (como la de las barras de la cabina) donde se ve el dibujo grande.
func _plate_style() -> StyleBoxFlat:
	var plate := _box(Color(0.8, 0.86, 0.94), BORDER, 3, 10, 6)
	return plate
