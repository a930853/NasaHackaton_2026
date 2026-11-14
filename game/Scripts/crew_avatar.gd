class_name CrewAvatar
extends Control
## Casco de astronauta de un rol, dibujado por código.
## El casco es blanco y se tiñe con el "albedo" del rol (los mismos colores que el mando web);
## cuando el astronauta está fuera de la base, el albedo pasa a gris.

## Albedo de cada rol (igual que controller/src/roles.js).
const ROLE_ALBEDO: Dictionary = {
	"engineer": Color("f5b940"),
	"biologist": Color("57c98b"),
	"doctor": Color("f17474"),
	"generalist": Color("68aaf0"),
}
const AWAY_ALBEDO: Color = Color(0.5, 0.52, 0.58)
const READY_TEXT_COLOR: Color = Color(0.45, 0.9, 0.55)
const AWAY_TEXT_COLOR: Color = Color(0.6, 0.62, 0.68)
const SHELL_BASE: Color = Color.WHITE          # color del casco antes de aplicar el albedo
const VISOR_COLOR: Color = Color(0.07, 0.11, 0.2)
const TEXT_HEIGHT: float = 38.0
const SEGMENTS: int = 32

var role: String
var role_name: String
var sols_left: int = 0   # Soles que le faltan para volver (0 = en la base)


func _init(role_id: String = "engineer", display_name: String = "") -> void:
	role = role_id
	role_name = display_name
	custom_minimum_size = Vector2(70, 100)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_away(0)


## 0 = en la base (color del rol); más de 0 = fuera (gris) y los Soles que faltan.
func set_away(sols: int) -> void:
	sols_left = sols
	if sols > 0:
		tooltip_text = "%s is outside. Back in %d Sol%s." % [role_name, sols, "" if sols == 1 else "s"]
	else:
		tooltip_text = "%s is at the base." % role_name
	queue_redraw()


func _draw() -> void:
	var away: bool = sols_left > 0
	var albedo: Color = AWAY_ALBEDO if away else ROLE_ALBEDO.get(role, Color.WHITE)
	var shell: Color = SHELL_BASE * albedo   # el albedo tiñe el casco blanco

	var area_height: float = maxf(size.y - TEXT_HEIGHT, 20.0)
	var radius: float = minf(size.x * 0.36, area_height * 0.5 - 2.0)
	var center := Vector2(size.x * 0.5, area_height * 0.5 + 1.0)

	# Orejeras del casco, sombra inferior y cúpula
	draw_circle(center + Vector2(-radius, radius * 0.1), radius * 0.2, shell.darkened(0.35))
	draw_circle(center + Vector2(radius, radius * 0.1), radius * 0.2, shell.darkened(0.35))
	draw_circle(center, radius, shell)
	draw_arc(center, radius * 0.93, PI * 0.1, PI * 0.9, SEGMENTS, shell.darkened(0.3), radius * 0.14, true)
	draw_arc(center, radius, 0.0, TAU, SEGMENTS, shell.darkened(0.5), 2.0, true)

	# Visera con su reflejo
	var visor_center: Vector2 = center + Vector2(0.0, radius * 0.08)
	var visor := PackedVector2Array()
	for i in range(SEGMENTS):
		var angle: float = TAU * float(i) / float(SEGMENTS)
		visor.append(visor_center + Vector2(cos(angle) * radius * 0.7, sin(angle) * radius * 0.5))
	draw_colored_polygon(visor, VISOR_COLOR)
	draw_arc(visor_center, radius * 0.46, PI * 1.12, PI * 1.55, 10, Color(1, 1, 1, 0.6), 2.5, true)

	# Nombre y estado
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y - 21.0), role_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
	var status: String = "READY" if not away else "OUTSIDE - %d Sol%s" % [sols_left, "" if sols_left == 1 else "s"]
	draw_string(font, Vector2(0.0, size.y - 6.0), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11,
		AWAY_TEXT_COLOR if away else READY_TEXT_COLOR)
