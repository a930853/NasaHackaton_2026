extends Node

const SCENES: Dictionary = {
	"menu": preload("res://Scenes/Main_menu.tscn"),
	"gameplay": preload("res://Scenes/Gameplay.tscn")
}
const FADE_DURATION := 1

@onready var scene_container: Node = $ContenedorEscena
@onready var fade_rect: ColorRect = $CapaTransicion/FundidoNegro
@onready var nasa_api: HTTPRequest = $SistemasGlobales/NasaApi

var is_transitioning: bool = false
var current_scene: Node = null


func _ready() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	Events.scene_change_requested.connect(change_scene)
	
	if nasa_api.has_method("fetch"):
		nasa_api.fetch()
	
	change_scene("menu")


func change_scene(scene_key: String) -> void:
	if is_transitioning:
		return
		
	if not SCENES.has(scene_key):
		push_error("Main: Invalid scene key -> " + scene_key)
		return
		
	is_transitioning = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if current_scene != null:
		await _fade(1.0)
		scene_container.remove_child(current_scene)
		current_scene.queue_free()
		current_scene = null
	else:
		fade_rect.color.a = 1.0
	
	var packed_scene: PackedScene = SCENES[scene_key]
	current_scene = packed_scene.instantiate()
	scene_container.add_child(current_scene)
	
	await _fade(0.0)
	
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	Events.scene_transition_finished.emit()


func _fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
