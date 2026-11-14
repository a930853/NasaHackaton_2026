extends Control

@onready var mainButtons: Control = $MenuButtons
@onready var lobby: Control = $Lobby
@onready var options: Control = $OptionsPanel

func _ready() -> void:
	lobby.visible = false
	mainButtons.visible = true
	


func _on_start_button_pressed() -> void:
	lobby.visible = true
	mainButtons.visible = false
	
func _on_start_exp_button_pressed() -> void:
	Events.scene_change_requested.emit("gameplay")
	await Events.scene_transition_finished


func _on_options_button_pressed() -> void:
	options.visible = true
