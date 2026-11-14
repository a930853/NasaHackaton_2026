class_name CrewPanel
extends PanelContainer
## Franja de la cabina con los 4 astronautas. Cada uno se ve verde si está en la base
## y gris si ha salido a hacer una tarea. Se actualiza solo cuando cambia la tripulación.

var _avatars: Dictionary = {}   # rol -> CrewAvatar


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.92)
	style.border_color = Color(0.25, 0.4, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for role in GameState.ROLES:
		var avatar := CrewAvatar.new(role, GameState.ROLE_NAMES[role])
		row.add_child(avatar)
		_avatars[role] = avatar


func _ready() -> void:
	GameState.crew_changed.connect(refresh)
	refresh()


## Pone cada avatar en su estado actual (los Soles que faltan dependen del Sol en curso).
func refresh() -> void:
	for role in _avatars:
		(_avatars[role] as CrewAvatar).set_away(GameState.away_sols_left(role))
