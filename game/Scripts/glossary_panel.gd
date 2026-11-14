class_name GlossaryPanel
extends UiOverlay
## Libro de Tecnicismos: lista de términos desbloqueados y su explicación.
## Se abre como modal encima del juego, sin pausarlo.

var _list: ItemList
var _detail: RichTextLabel
var _ids: Array[String] = []


func _init() -> void:
	super(Vector2(900, 520))

	content.add_child(make_title("Science Words Book"))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(280, 0)
	_list.item_selected.connect(_on_item_selected)
	row.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_detail)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(close)
	content.add_child(close_button)


func _ready() -> void:
	GlossaryManager.term_unlocked.connect(_on_term_unlocked)


func open() -> void:
	_refresh()
	super()


func _refresh() -> void:
	_ids = GlossaryManager.get_unlocked_ids()
	_list.clear()
	for term_id in _ids:
		_list.add_item(str(GlossaryManager.get_term(term_id).get("title", term_id)))
	if _ids.is_empty():
		_detail.text = "You have not found any words yet. They appear as the game goes on!"
	else:
		_list.select(0)
		_show_term(_ids[0])


func _on_item_selected(index: int) -> void:
	_show_term(_ids[index])


func _show_term(term_id: String) -> void:
	var term: Dictionary = GlossaryManager.get_term(term_id)
	_detail.text = "[b]%s[/b]\n\n%s\n\n[i]NASA fact:[/i] %s" % [
		term.get("title", term_id), term.get("definition", ""), term.get("nasa_fact", "")]


func _on_term_unlocked(_term_id: String, _title: String) -> void:
	if visible:
		_refresh()
