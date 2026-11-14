class_name EventButtonFace
extends Control
## Cara del botón redondo EVENT: un botón rojo en pixel art (res://Images/Evento.png, y
## Evento_pulsado.png cuando es la pantalla que se está viendo). Sin aros ni resplandor.
## Cuando hay un evento importante, aparece una exclamación encima que da saltitos.
## Va como hijo de un Button.

const ART_NORMAL: String = "res://Images/Evento.png"
const ART_PRESSED: String = "res://Images/Evento_pulsado.png"
const ART_PIXELS: float = 32.0              # lado del pixel art original
const GROW: float = 1.3                     # cuánto más grande que el botón se dibuja
const HOVER_TINT: Color = Color(1.15, 1.1, 1.1)
const LABEL: String = "EVENT"
const LABEL_COLOR: Color = Color(1.0, 0.95, 0.9)
const LABEL_SHADOW: Color = Color(0.25, 0.02, 0.05)
const FALLBACK_RED: Color = Color(0.84, 0.12, 0.15)

## Signo de exclamación en una cuadrícula de 5x13 "píxeles": 1 = amarillo, 0 = vacío.
const BANG_ROWS: Array[String] = [
	"01110", "11111", "11111", "11111", "11111", "11111", "01110", "01110", "00000", "01110", "11111", "11111", "01110",
]
const BANG_FILL: Color = Color(1.0, 0.85, 0.1)
const BANG_BORDER: Color = Color(0.06, 0.03, 0.05)

static var _textures: Dictionary = {}       # ruta -> Texture2D, se cargan una sola vez

## Muestra la exclamación (la pone la pantalla principal según el evento actual).
var alert: bool = false:
	set(value):
		alert = value
		queue_redraw()

var _button: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nítido


func _ready() -> void:
	_button = get_parent() as Button
	if _button != null:
		_button.toggled.connect(func(_on: bool) -> void: queue_redraw())
		_button.mouse_entered.connect(queue_redraw)
		_button.mouse_exited.connect(queue_redraw)


func _process(_delta: float) -> void:
	if alert:
		queue_redraw()  # la exclamación salta


func _draw() -> void:
	var pressed: bool = _button != null and _button.button_pressed
	var hovering: bool = _button != null and _button.is_hovered()

	# Un solo cuadrado centrado. Es más grande que el hueco del botón (GROW): el pixel art
	# puede sobresalir un poco del marco, y se escala con vecino más cercano para no suavizarlo.
	var side: float = minf(size.x, size.y) * GROW
	var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var unit: float = side / ART_PIXELS

	var texture: Texture2D = _get_art(ART_PRESSED if pressed else ART_NORMAL)
	if texture != null:
		draw_texture_rect(texture, box, false, HOVER_TINT if hovering else Color.WHITE)
	else:
		# Si la imagen aún no está importada, un círculo rojo evita dejar un hueco.
		draw_circle(box.get_center(), side * 0.38, FALLBACK_RED)

	# Etiqueta sobre la tapa del botón
	var font: Font = ThemeDB.fallback_font
	var font_size: int = clampi(int(side * 0.16), 11, 28)
	var label_y: float = box.position.y + (17.0 if pressed else 15.0) * unit + float(font_size) * 0.4
	draw_string(font, Vector2(1.0, label_y + 1.0), LABEL, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, LABEL_SHADOW)
	draw_string(font, Vector2(0.0, label_y), LABEL, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, LABEL_COLOR)

	if alert:
		_draw_exclamation(box, unit)


## Exclamación amarilla con borde negro, encima del botón y dando saltitos (en pasos de un píxel).
func _draw_exclamation(box: Rect2, unit: float) -> void:
	var pixel: float = maxf(2.0, floorf(unit * 0.5))
	var cols: int = (BANG_ROWS[0] as String).length()
	var width: float = float(cols) * pixel
	var height: float = float(BANG_ROWS.size()) * pixel
	var hop: float = roundf(absf(sin(Time.get_ticks_msec() / 220.0)) * 3.0) * pixel
	var origin := Vector2(box.get_center().x - width * 0.5, box.position.y - height * 0.45 - hop)

	# Primero el borde (la silueta ensanchada un píxel hacia los lados) y luego el relleno
	for row in range(BANG_ROWS.size()):
		var line: String = BANG_ROWS[row]
		for col in range(cols):
			if line[col] != "1":
				continue
			var at: Vector2 = origin + Vector2(float(col), float(row)) * pixel
			draw_rect(Rect2(at - Vector2(pixel, pixel), Vector2(pixel, pixel) * 3.0), BANG_BORDER)
	for row in range(BANG_ROWS.size()):
		var line: String = BANG_ROWS[row]
		for col in range(cols):
			if line[col] == "1":
				draw_rect(Rect2(origin + Vector2(float(col), float(row)) * pixel, Vector2(pixel, pixel)), BANG_FILL)


## Carga la imagen la primera vez. Se hace aquí y no con preload para que el juego
## arranque aunque Godot todavía no haya importado los PNG.
func _get_art(path: String) -> Texture2D:
	if not _textures.has(path) and ResourceLoader.exists(path):
		_textures[path] = load(path)
	return _textures.get(path, null)
