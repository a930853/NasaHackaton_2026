class_name StatIcon
extends Control
## Logo de una estadística (las imágenes de res://Images/) que se llena como un medidor.
##
## Los logos son pixel art de línea negra sobre fondo transparente. Se dibujan tal cual,
## con su borde negro, encima de un relleno de color (el botón tiene la cara clara para
## que el borde se lea). El relleno usa un shader que recolorea la máscara del interior.
## El interior de cada dibujo se calcula una vez rellenando desde fuera: lo que no se
## alcanza desde el borde es "dentro", y esa zona se rellena de abajo hacia arriba según el nivel.
## Si queda poco (menos del 30%), el relleno se pone rojo y parpadea.

const SALUD: Texture2D = preload("res://Images/Salud.png")
const OXIGENO: Texture2D = preload("res://Images/Oxigeno.png")
const ENERGIA: Texture2D = preload("res://Images/Energia.png")
const INTEGRIDAD: Texture2D = preload("res://Images/Integridad.png")
## Logo de cada estadística por su clave en GameState (lo usan el HUD y la pantalla final).
const BY_STAT: Dictionary = {
	"health": SALUD, "oxygen": OXIGENO, "energy": ENERGIA, "integrity": INTEGRIDAD,
}

const RECOLOR_SHADER: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
"""
const SOLID_ALPHA: float = 0.3        # a partir de aquí un píxel cuenta como línea del dibujo
const EMPTY_ALPHA: float = 0.12       # opacidad de la parte vacía (apenas un tinte)
const FILL_ALPHA: float = 1.0
const LOW_LEVEL: float = 0.3
const LOW_COLOR: Color = Color(1.0, 0.3, 0.3)
const FILL_SECONDS: float = 0.5
const ICON_SCALE: float = 0.92        # parte del botón que ocupa el logo

var accent: Color = Color.WHITE
var level: float = 1.0:               # lo que se ve ahora (0..1); cambia suave hacia el valor real
	set(value):
		level = clampf(value, 0.0, 1.0)
		set_process(level <= LOW_LEVEL)
		_update_fill_tint()
		queue_redraw()

var _outline: TextureRect
var _fill_texture: ImageTexture
var _fill_material: ShaderMaterial
var _tween: Tween = null


func _init(icon: Texture2D = SALUD, icon_color: Color = Color.WHITE) -> void:
	accent = icon_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # los logos son de 64 px: se ven nítidos

	_fill_texture = _make_fill_mask(icon)
	_fill_material = _make_recolor_material(accent)
	material = _fill_material   # recolorea lo que se dibuja con _draw (el relleno)

	_outline = TextureRect.new()
	_outline.texture = icon
	_outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sin material: el contorno se ve como en la imagen original, en negro.
	add_child(_outline)
	resized.connect(_layout_outline)


func _process(_delta: float) -> void:
	_update_fill_tint()  # parpadeo cuando queda poco
	queue_redraw()


## Llena el logo hasta `value` (0..1), con animación o de golpe.
func set_level(value: float, animate: bool = true) -> void:
	if _tween != null:
		_tween.kill()
	if not animate:
		level = value
		return
	_tween = create_tween()
	_tween.tween_property(self, "level", clampf(value, 0.0, 1.0), FILL_SECONDS)


## Cuadrado centrado donde se dibuja el logo (el mismo para el relleno y para el contorno).
func _icon_box() -> Rect2:
	var side: float = minf(size.x, size.y) * ICON_SCALE
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _layout_outline() -> void:
	var box: Rect2 = _icon_box()
	_outline.position = box.position
	_outline.size = box.size


func _draw() -> void:
	var box: Rect2 = _icon_box()
	var tex_size: Vector2 = _fill_texture.get_size()

	# Parte vacía (muy tenue) y parte llena, recortada por la altura del nivel
	draw_texture_rect(_fill_texture, box, false, Color(1, 1, 1, EMPTY_ALPHA))
	if level > 0.0:
		var fill_height: float = box.size.y * level
		var dest := Rect2(box.position.x, box.end.y - fill_height, box.size.x, fill_height)
		var source := Rect2(0.0, tex_size.y * (1.0 - level), tex_size.x, tex_size.y * level)
		draw_texture_rect_region(_fill_texture, dest, source, Color(1, 1, 1, FILL_ALPHA))


func _update_fill_tint() -> void:
	if _fill_material == null:
		return
	var color: Color = accent
	if level <= LOW_LEVEL:
		color = LOW_COLOR
		color.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 130.0)
	_fill_material.set_shader_parameter("tint", color)


func _make_recolor_material(color: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = RECOLOR_SHADER
	var recolor := ShaderMaterial.new()
	recolor.shader = shader
	recolor.set_shader_parameter("tint", color)
	return recolor


## Máscara del interior del dibujo (más la propia línea): blanco opaco dentro, transparente fuera.
## Se calcula rellenando desde los bordes de la imagen: lo que no se alcanza está "dentro".
func _make_fill_mask(icon: Texture2D) -> ImageTexture:
	var source: Image = icon.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var width: int = source.get_width()
	var height: int = source.get_height()

	var outside := PackedByteArray()
	outside.resize(width * height)
	var pending: Array[Vector2i] = []
	for x in range(width):
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, height - 1))
	for y in range(height):
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(width - 1, y))

	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
			continue
		var index: int = point.y * width + point.x
		if outside[index] == 1 or source.get_pixel(point.x, point.y).a >= SOLID_ALPHA:
			continue
		outside[index] = 1
		pending.append(Vector2i(point.x + 1, point.y))
		pending.append(Vector2i(point.x - 1, point.y))
		pending.append(Vector2i(point.x, point.y + 1))
		pending.append(Vector2i(point.x, point.y - 1))

	var mask: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var inside_pixels: int = 0
	for y in range(height):
		for x in range(width):
			if outside[y * width + x] == 0:
				mask.set_pixel(x, y, Color.WHITE)
				inside_pixels += 1
	# Si el dibujo no estuviera cerrado, el relleno "se escaparía": mejor rellenar toda la imagen.
	if inside_pixels * 20 < width * height:
		mask.fill(Color.WHITE)
	return ImageTexture.create_from_image(mask)
