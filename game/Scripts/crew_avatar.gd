class_name CrewAvatar
extends Control
## Casco de astronauta de un rol, con la imagen res://Images/Astronauta.png.
## La imagen es un casco blanco: se tiñe con el "albedo" del rol (modulate) y cuando el
## astronauta está fuera de la base el albedo pasa a gris.

const HELMET_PATH: String = "res://Images/Astronauta.png"

## Albedo de cada rol. El polivalente (Generalist) se queda en blanco, sin teñir.
const ROLE_ALBEDO: Dictionary = {
	"engineer": Color(1.0, 0.85, 0.2),     # amarillo
	"biologist": Color(0.4, 0.9, 0.5),     # verde
	"doctor": Color(1.0, 0.4, 0.4),        # rojo
	"generalist": Color(1.0, 1.0, 1.0),    # blanco
}
const AWAY_ALBEDO: Color = Color(0.45, 0.47, 0.52)
const READY_TEXT_COLOR: Color = Color(0.45, 0.9, 0.55)
const AWAY_TEXT_COLOR: Color = Color(0.6, 0.62, 0.68)
const TEXT_HEIGHT: float = 38.0

static var _helmet_texture: Texture2D = null   # se carga una sola vez y la comparten los 4 avatares

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
		tooltip_text = "%s is busy. Back in %d Sol%s." % [role_name, sols, "" if sols == 1 else "s"]
	else:
		tooltip_text = "%s is at the base." % role_name
	queue_redraw()


func _draw() -> void:
	var away: bool = sols_left > 0
	var albedo: Color = AWAY_ALBEDO if away else ROLE_ALBEDO.get(role, Color.WHITE)

	var area_height: float = maxf(size.y - TEXT_HEIGHT, 20.0)
	var side: float = minf(size.x * 0.9, area_height)
	var helmet := Rect2(Vector2((size.x - side) * 0.5, (area_height - side) * 0.5 + 1.0), Vector2(side, side))

	var texture: Texture2D = get_helmet()
	if texture != null:
		draw_texture_rect(texture, helmet, false, albedo)
	else:
		# Si la imagen aún no está importada, un círculo del mismo color evita dejar un hueco.
		draw_circle(helmet.get_center(), side * 0.42, albedo)

	# Nombre y estado
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, size.y - 21.0), role_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color.WHITE)
	var status: String = "READY" if not away else "BUSY - %d Sol%s" % [sols_left, "" if sols_left == 1 else "s"]
	draw_string(font, Vector2(0.0, size.y - 6.0), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11,
		AWAY_TEXT_COLOR if away else READY_TEXT_COLOR)


## Carga la imagen del casco la primera vez. Se hace aquí y no con preload para que el
## juego arranque aunque Godot todavía no haya importado Astronauta.png.
static func get_helmet() -> Texture2D:
	if _helmet_texture == null and ResourceLoader.exists(HELMET_PATH):
		_helmet_texture = load(HELMET_PATH)
	return _helmet_texture
