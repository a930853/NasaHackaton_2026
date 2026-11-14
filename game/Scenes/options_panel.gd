extends Control

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Sincroniza los sliders con el volumen actual de los buses al cargar
	self.visible = false
	master_slider.value = _get_bus_linear(&"Master")
	music_slider.value = _get_bus_linear(&"Music")
	sfx_slider.value = _get_bus_linear(&"SFX")
	
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)


func _on_master_changed(value: float) -> void:
	_set_bus_linear(&"Master", value)


func _on_music_changed(value: float) -> void:
	_set_bus_linear(&"Music", value)


func _on_sfx_changed(value: float) -> void:
	_set_bus_linear(&"SFX", value)


func _on_close_pressed() -> void:
	Events.sfx_requested.emit("click", 0.05)
	hide()


func _set_bus_linear(bus_name: StringName, linear_val: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
	AudioServer.set_bus_mute(bus_idx, linear_val <= 0.01)


func _get_bus_linear(bus_name: StringName) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1 or AudioServer.is_bus_mute(bus_idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
