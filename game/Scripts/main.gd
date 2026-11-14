extends Node

const SCENES: Dictionary = {
	"menu": preload("res://Scenes/Main_menu.tscn"),
	"intro": preload("res://Scenes/Intro.tscn"),
	"gameplay": preload("res://Scenes/Gameplay.tscn")
}
const FADE_DURATION := 0.4

## Música de cada escena: el menú usa Chill_Space2026; la llegada a Marte (intro) y la
## partida usan la banda sonora de Marte, Chill_MN. Las escenas que no aparecen siguen igual.
const MENU_MUSIC: AudioStream = preload("res://Sound/Soundtrack/Chill_Space2026.mp3")
const MARS_MUSIC: AudioStream = preload("res://Sound/Soundtrack/Chill_MN.mp3")
const SCENE_MUSIC: Dictionary = {
	"menu": MENU_MUSIC,
	"intro": MARS_MUSIC,
	"gameplay": MARS_MUSIC,
}
const MUSIC_FADE_SECONDS := 0.8
const MUSIC_SILENT_DB := -40.0

@onready var scene_container: Node = $ContenedorEscena
@onready var music: AudioStreamPlayer2D = $SistemasGlobales/Musica_Ambiente
@onready var fade_rect: ColorRect = $CapaTransicion/FundidoNegro
@onready var nasa_api: HTTPRequest = $SistemasGlobales/NasaApi

var _music_tween: Tween = null
var is_transitioning: bool = false
var current_scene: Node = null


func _ready() -> void:
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Los .mp3 se importaron sin bucle: la música se acabaría y se quedaría en silencio.
	for track in [MENU_MUSIC, MARS_MUSIC]:
		if track is AudioStreamMP3:
			(track as AudioStreamMP3).loop = true

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
	_change_music(SCENE_MUSIC.get(scene_key))
	
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


## Cambia la música con un fundido: baja la actual, pone la nueva en bucle y la sube.
## Si ya suena esa pista (o la escena no tiene música propia) no hace nada.
func _change_music(new_stream: AudioStream) -> void:
	if new_stream == null or music.stream == new_stream:
		return
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween()
	if music.playing:
		_music_tween.tween_property(music, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_SECONDS)
	_music_tween.tween_callback(func() -> void:
		music.stream = new_stream
		music.play())
	_music_tween.tween_property(music, "volume_db", 0.0, MUSIC_FADE_SECONDS)


func _fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
