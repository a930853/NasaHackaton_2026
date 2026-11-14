class_name StatIcon
extends Control
## Dibujo de una estadística que se llena como un medidor (de abajo hacia arriba).
## Corazón = Salud, burbuja "O2" = Oxígeno, rayo = Energía, cúpula = Fuerza de la base.
## Si queda poco (menos del 30%), el dibujo se pone rojo y parpadea.
## Todo se dibuja por código, sin imágenes.

enum Kind { HEART, BUBBLE, BOLT, BASE }

const EMPTY_FILL: Color = Color(0.16, 0.2, 0.28)
const DOOR_COLOR: Color = Color(0.05, 0.08, 0.14)
const LOW_LEVEL: float = 0.3
const LOW_COLOR: Color = Color(1.0, 0.3, 0.3)
const FILL_SECONDS: float = 0.5
const ICON_SCALE: float = 0.9   # parte del botón que ocupa el dibujo
const CIRCLE_POINTS: int = 36

var kind: int = Kind.HEART
var accent: Color = Color.WHITE
var level: float = 1.0:          # lo que se ve ahora (0..1); cambia suave hacia el valor real
	set(value):
		level = clampf(value, 0.0, 1.0)
		set_process(level <= LOW_LEVEL)
		queue_redraw()

var _tween: Tween = null


func _init(icon_kind: int = Kind.HEART, icon_color: Color = Color.WHITE) -> void:
	kind = icon_kind
	accent = icon_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()  # parpadeo cuando queda poco


## Llena el dibujo hasta `value` (0..1), con animación o de golpe.
func set_level(value: float, animate: bool = true) -> void:
	if _tween != null:
		_tween.kill()
	if not animate:
		level = value
		return
	_tween = create_tween()
	_tween.tween_property(self, "level", clampf(value, 0.0, 1.0), FILL_SECONDS)


func _draw() -> void:
	var side: float = minf(size.x, size.y) * ICON_SCALE
	var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var shapes: Array[PackedVector2Array] = _shapes(box)

	var color: Color = accent
	var low: bool = level <= LOW_LEVEL
	if low:
		color = LOW_COLOR
		color.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 130.0)

	# 1) silueta vacía
	for shape in shapes:
		draw_colored_polygon(shape, EMPTY_FILL)

	# 2) parte llena: la silueta recortada por una línea horizontal a la altura del nivel
	var fill_top: float = box.end.y - box.size.y * level
	var clip := PackedVector2Array([
		Vector2(box.position.x - 3.0, fill_top), Vector2(box.end.x + 3.0, fill_top),
		Vector2(box.end.x + 3.0, box.end.y + 3.0), Vector2(box.position.x - 3.0, box.end.y + 3.0)])
	if level > 0.0:
		for shape in shapes:
			if level >= 0.999:
				draw_colored_polygon(shape, color)
				continue
			for part in Geometry2D.intersect_polygons(shape, clip):
				if part.size() >= 3:
					draw_colored_polygon(part, color)

	# 3) detalles y contorno
	_draw_details(box)
	for shape in shapes:
		var outline: PackedVector2Array = shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, Color(accent, 0.95), 2.0, true)


func _draw_details(box: Rect2) -> void:
	match kind:
		Kind.BUBBLE:
			var font: Font = ThemeDB.fallback_font
			var font_size: int = int(box.size.y * 0.36)
			var base: Vector2 = box.position + Vector2(box.size.x * 0.06, box.size.y * 0.58 + font_size * 0.35)
			draw_string(font, base, "O2", HORIZONTAL_ALIGNMENT_CENTER, box.size.x * 0.8, font_size, DOOR_COLOR)
		Kind.BASE:
			# Puerta de la base
			draw_rect(Rect2(_at(box, Vector2(0.42, 0.72)), box.size * Vector2(0.16, 0.23)), DOOR_COLOR)


# ---------------------------------------------------------------------- Formas

func _shapes(box: Rect2) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	match kind:
		Kind.HEART:
			shapes.append(_map(_heart_points(), box))
		Kind.BUBBLE:
			shapes.append(_map(_circle(Vector2(0.46, 0.6), 0.38), box))
			shapes.append(_map(_circle(Vector2(0.84, 0.2), 0.11), box))
			shapes.append(_map(_circle(Vector2(0.93, 0.42), 0.055), box))
		Kind.BOLT:
			shapes.append(_map(PackedVector2Array([
				Vector2(0.60, 0.00), Vector2(0.20, 0.55), Vector2(0.45, 0.55), Vector2(0.30, 1.00),
				Vector2(0.80, 0.40), Vector2(0.55, 0.40), Vector2(0.78, 0.00)]), box))
		Kind.BASE:
			shapes.append(_map(_dome_points(), box))
	return shapes


func _at(box: Rect2, unit: Vector2) -> Vector2:
	return box.position + unit * box.size


## Puntos en el cuadrado 0..1 -> píxeles del recuadro del dibujo.
func _map(points: PackedVector2Array, box: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(_at(box, point))
	return result


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(CIRCLE_POINTS):
		var angle: float = TAU * float(i) / float(CIRCLE_POINTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Corazón con la curva clásica x = 16 sin³t, y = 13 cos t - 5 cos 2t - 2 cos 3t - cos 4t.
func _heart_points() -> PackedVector2Array:
	var raw := PackedVector2Array()
	for i in range(48):
		var t: float = TAU * float(i) / 48.0
		raw.append(Vector2(
			16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))))
	var min_p: Vector2 = raw[0]
	var max_p: Vector2 = raw[0]
	for point in raw:
		min_p = min_p.min(point)
		max_p = max_p.max(point)
	var points := PackedVector2Array()
	for point in raw:
		points.append((point - min_p) / (max_p - min_p))
	return points


## Cúpula de la base: medio círculo con un rectángulo debajo.
func _dome_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := Vector2(0.5, 0.62)
	var radius: float = 0.46
	for i in range(CIRCLE_POINTS / 2 + 1):
		var angle: float = PI + PI * float(i) / float(CIRCLE_POINTS / 2)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	points.append(Vector2(0.96, 0.96))
	points.append(Vector2(0.04, 0.96))
	return points
