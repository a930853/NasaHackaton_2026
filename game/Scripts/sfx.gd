extends Node

const POOL_SIZE := 8
const BUS_SFX := &"SFX"

# Precarga tus archivos desde res://Sounds/SFX/
const SOUNDS: Dictionary = {
	"rocket_landing": preload("res://Sound/SFX/Landing_SFX.mp3"),
	"success": preload("res://Sound/SFX/Succes_SFX.mp3"),
	"failure": preload("res://Sound/SFX/Failure_SFX.mp3"),
	"door": preload("res://Sound/SFX/Door_SFX.mp3"),
	"intercom": preload("res://Sound/SFX/IntercomsMessage_SFX.mp3"),
	#"click": preload("res://Sounds/SFX/click.ogg"),
	#"alert": preload("res://Sounds/SFX/alert.ogg"),
	#"nfc_scan": preload("res://Sounds/SFX/nfc_scan.ogg"),
	#"success": preload("res://Sounds/SFX/success.ogg")
}

# Volumen (dB) de los sonidos que no deben sonar a tope. El mensaje de la Tierra suena "de fondo".
const VOLUME_DB: Dictionary = {
	"intercom": -8.0,
}

var _players: Array[AudioStreamPlayer] = []
var _next_index: int = 0


func _ready() -> void:
	# Crea un pool fijo de reproductores apuntando al bus SFX
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)
	
	Events.sfx_requested.connect(play_sfx)


func play_sfx(sfx_key: String, pitch_variance: float = 0.0) -> void:
	if not SOUNDS.has(sfx_key):
		push_warning("SfxManager: Sound key not found -> " + sfx_key)
		return
	
	var player := _get_available_player()
	player.stream = SOUNDS[sfx_key]
	player.volume_db = VOLUME_DB.get(sfx_key, 0.0)  # se reinicia siempre: el reproductor se recicla
	
	# Variación ligera de tono opcional para evitar repetición robótica en clics
	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
		
	player.play()


func _get_available_player() -> AudioStreamPlayer:
	# Busca un reproductor libre; si todos suenan, recicla el más antiguo (round-robin)
	for player in _players:
		if not player.playing:
			return player
	
	var fallback := _players[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	return fallback
