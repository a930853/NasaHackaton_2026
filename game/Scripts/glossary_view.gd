class_name GlossaryView
extends HBoxContainer
## Libro de palabras científicas dentro de la pantalla de la cabina:
## lista de términos desbloqueados a la izquierda y su explicación a la derecha.

var _list: ItemList
var _detail: RichTextLabel
var _ids: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 10)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(150, 0)
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_selected.connect(_on_item_selected)
	add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 15)
	_detail.add_theme_font_size_override("bold_font_size", 17)
	add_child(_detail)


func _ready() -> void:
	GlossaryManager.term_unlocked.connect(_on_term_unlocked)


## Vuelve a rellenar la lista con los términos desbloqueados hasta ahora.
func refresh() -> void:
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
	if is_visible_in_tree():
		refresh()
