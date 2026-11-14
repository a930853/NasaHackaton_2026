extends Node
## Mejoras sobre el borrador: fundido entre escenas, remove_child antes de
## queue_free (si no, el nodo viejo sigue en el árbol ese frame), y bloqueo
## de cambios simultáneos.

@onready var contenedor: Node = $ContenedorEscena
@onready var fundido: ColorRect = $CapaTransicion/FundidoNegro
@onready var nasa: HTTPRequest = $SistemasGlobales/NasaAPI

var _cambiando := false


func _ready() -> void:
	nasa.fetch()  # no bloquea: el menú carga ya y el dato llega cuando llegue
	await cargar_escena(load("res://scenes/menu_principal.tscn"))


func cargar_escena(nueva: PackedScene) -> void:
	if _cambiando:
		return
	_cambiando = true
	var tw := create_tween()
	tw.tween_property(fundido, "modulate:a", 1.0, 0.25)
	await tw.finished
	for hijo in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()
	contenedor.add_child(nueva.instantiate())
	tw = create_tween()
	tw.tween_property(fundido, "modulate:a", 0.0, 0.25)
	await tw.finished
	_cambiando = false
