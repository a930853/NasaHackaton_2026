extends Node
## Autoload "GlossaryManager": Libro de Tecnicismos.
## Los términos viven en res://Data/glossary.json. Cada vez que aparece un evento con
## términos asociados se desbloquean aquí y la UI muestra un aviso.

signal term_unlocked(term_id: String, title: String)

const GLOSSARY_PATH: String = "res://Data/glossary.json"

var _terms: Dictionary = {}


func _ready() -> void:
	var file: FileAccess = FileAccess.open(GLOSSARY_PATH, FileAccess.READ)
	if file == null:
		push_error("GlossaryManager: could not open " + GLOSSARY_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_terms = parsed.get("terms", {})
	else:
		push_error("GlossaryManager: invalid JSON in " + GLOSSARY_PATH)


## Desbloquea un término (si existe y aún no estaba desbloqueado).
func unlock(term_id: String) -> void:
	if not _terms.has(term_id):
		push_warning("GlossaryManager: unknown term '%s'." % term_id)
		return
	if term_id in GameState.unlocked_terms:
		return
	GameState.unlocked_terms.append(term_id)
	term_unlocked.emit(term_id, str(_terms[term_id].get("title", term_id)))


func unlock_many(term_ids: Array) -> void:
	for term_id in term_ids:
		unlock(str(term_id))


func get_term(term_id: String) -> Dictionary:
	return _terms.get(term_id, {})


## IDs desbloqueados, ordenados alfabéticamente por título.
func get_unlocked_ids() -> Array[String]:
	var ids: Array[String] = GameState.unlocked_terms.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(_terms[a].get("title", a)) < str(_terms[b].get("title", b)))
	return ids


func total_terms() -> int:
	return _terms.size()
