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
	"click": preload("res://Sound/SFX/Click.mp3"),
	"texting": preload("res://Sound/SFX/Texting_SFX.mp3"),
	"sandstorm": preload("res://Sound/SFX/Sandstorm_SFX.mp3"),
	#"alert": preload("res://Sounds/SFX/alert.ogg"),
	#"nfc_scan": preload("res://Sounds/SFX/nfc_scan.ogg"),
	#"success": preload("res://Sounds/SFX/success.ogg")
}

# Volumen (dB) de los sonidos que no deben sonar a tope. El mensaje de la Tierra suena "de fondo".
const VOLUME_DB: Dictionary = {
	"intercom": -8.0,
	"texting": -6.0,
	"sandstorm": -4.0,
}

## Sonidos que se repiten en bucle hasta que alguien pide pararlos con Events.sfx_stop_requested
## (el texto de un evento suena a «teclear» mientras se va escribiendo).
const LOOPING: Array[String] = ["texting", "sandstorm"]
const LOOP_FADE_SECONDS: float = 0.12
## Fundido de salida de cada sonido en bucle (la tormenta se va apagando poco a poco).
const LOOP_FADE_BY_KEY: Dictionary = {
	"sandstorm": 1.2,
}
const SILENT_DB: float = -40.0

var _loop_players: Dictionary = {}   # clave -> AudioStreamPlayer propio del bucle
var _loop_fades: Dictionary = {}     # clave -> Tween de fundido de salida en curso

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
	Events.sfx_stop_requested.connect(stop_sfx)


func play_sfx(sfx_key: String, pitch_variance: float = 0.0) -> void:
	if not SOUNDS.has(sfx_key):
		push_warning("SfxManager: Sound key not found -> " + sfx_key)
		return
	
	if sfx_key in LOOPING:
		_start_loop(sfx_key)
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


## Empieza un sonido en bucle (si ya suena, no hace nada). Tiene su propio reproductor para que
## el resto de efectos no lo corten.
func _start_loop(sfx_key: String) -> void:
	var player: AudioStreamPlayer = _loop_players.get(sfx_key)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_loop_players[sfx_key] = player
	_cancel_fade(sfx_key)   # si se estaba apagando, vuelve a sonar entero
	if player.playing:
		player.volume_db = VOLUME_DB.get(sfx_key, 0.0)
		return
	var stream: AudioStream = SOUNDS[sfx_key]
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true   # los .mp3 se importan sin bucle
	player.stream = stream
	player.volume_db = VOLUME_DB.get(sfx_key, 0.0)
	player.pitch_scale = 1.0
	player.play()


## Para un sonido en bucle con un fundido muy corto (para que no suene a corte).
func stop_sfx(sfx_key: String) -> void:
	var player: AudioStreamPlayer = _loop_players.get(sfx_key)
	if player == null or not player.playing:
		return
	_cancel_fade(sfx_key)
	var tween := create_tween()
	_loop_fades[sfx_key] = tween
	tween.tween_property(player, "volume_db", SILENT_DB, float(LOOP_FADE_BY_KEY.get(sfx_key, LOOP_FADE_SECONDS)))
	tween.tween_callback(player.stop)


func _cancel_fade(sfx_key: String) -> void:
	var fade: Tween = _loop_fades.get(sfx_key)
	if fade != null:
		fade.kill()
	_loop_fades.erase(sfx_key)


func _get_available_player() -> AudioStreamPlayer:
	# Busca un reproductor libre; si todos suenan, recicla el más antiguo (round-robin)
	for player in _players:
		if not player.playing:
			return player
	
	var fallback := _players[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	return fallback
