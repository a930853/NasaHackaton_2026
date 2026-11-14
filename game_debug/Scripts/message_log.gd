class_name MessageLog
extends RichTextLabel
## Panel con los mensajes en bruto que entran y salen, más notas propias.
##   →  enviado por Godot
##   ←  recibido del backend
##   ·  nota de la pantalla de depuración

const COLOR_SENT := "#7fb3ff"
const COLOR_RECEIVED := "#8fe38f"
const COLOR_NOTE := "#c0c0c0"
const COLOR_ERROR := "#ff7a7a"


func _ready() -> void:
	bbcode_enabled = true
	scroll_following = true
	selection_enabled = true
	context_menu_enabled = true  # clic derecho > copiar


func add_sent(message: String) -> void:
	_add("→", COLOR_SENT, message)


func add_received(message: String) -> void:
	_add("←", COLOR_RECEIVED, message)


func add_note(message: String, is_error := false) -> void:
	_add("·", COLOR_ERROR if is_error else COLOR_NOTE, message)


func _add(arrow: String, color: String, message: String) -> void:
	var time := Time.get_time_string_from_system()
	# "[" abriría una etiqueta BBCode: se escapa para que el JSON salga tal cual.
	var safe := message.replace("[", "[lb]")
	append_text("[color=#808080]%s[/color] [color=%s]%s %s[/color]\n" % [time, color, arrow, safe])
