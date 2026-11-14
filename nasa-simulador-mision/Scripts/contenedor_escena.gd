extends Node


@onready var contenedor = $ContenedorEscena

const SCENE_MENU = preload("res://Scenes/Main_menu.tscn")
const SCENE_GAMEPLAY = preload("res://Scenes/Gameplay.tscn")

func _ready():
	cargar_escena(SCENE_MENU)


func cargar_escena(nueva_escena: PackedScene):
	#Borrar la que hay en el contenedor
	for hijo in contenedor.get_children():
		hijo.queue_free()
		
	#Instanciar nueva escena
	var instancia = nueva_escena.instantiate()
	contenedor.add_child(instancia)
