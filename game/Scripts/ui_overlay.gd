class_name UiOverlay
extends Control
## Ventana modal reutilizable: fondo oscuro que bloquea clics + panel centrado.
## Se rellena añadiendo nodos a `content`. Se construye por código para no
## depender de una escena por cada ventana (glosario, ayuda de la Tierra, fin de partida).

var content: VBoxContainer


func _init(panel_size: Vector2 = Vector2(700, 420)) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


## Vacía el contenido (para reconstruirlo cada vez que se abre).
func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	return label


func make_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
